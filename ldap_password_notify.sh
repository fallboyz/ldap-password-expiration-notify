#!/bin/bash
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <fallboyz@umount.net> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.
# ----------------------------------------------------------------------------
# script name : ldap_password_notify.sh
# description : Notify LDAP users of upcoming password expiration and send daily report to admin
# author      : island_of_hermit <fallboyz@umount.net>
# date        : 2025-04-28
# modify      : 2025-06-30
#
# set -x
#
# LDAP 서버 URI 설정 (ldap:// 또는 ldaps://)
# ldap_uri="ldaps://ldap.example.com:636"
ldap_uri="ldap://ldap.example.com:389"

# 바인드 계정 설정
ldap_bind_dn="cn=binduser,ou=Users,dc=ldap,dc=example,dc=com"
ldap_bind_pw="YourSecretPassword"

## TLS 사용 여부 설정
# true  = ldap:// 프로토콜 사용 시 StartTLS 적용 (-ZZ 옵션 추가)
# false = 일반 평문 접속(ldap://) 또는 SSL 접속(ldaps://) 시
use_starttls=false

## TLS 인증서 검증 활성화 여부
# true  = 서버 인증서 검증 (tls_cacert_path 변수에 경로 필요)
# false = 인증서 검증 비활성화
use_tls_verify=false

# 인증서 검증을 활성화할 경우 사용되는 CA 인증서 경로
# (use_tls_verify=true 일 때만 적용)
tls_cacert_path="/etc/ssl/certs/ca-bundle.crt"

## LDAP 비밀번호 정책 설정
# default_policy_dn:
#   - 사용자별 비밀번호 정책(pwdPolicySubentry)이 없을 경우 적용할 글로벌 정책 DN
#   - 글로벌 정책이 있을 경우에만 주석 해제 후 작성
#
# default_max_age:
#   - 정책 정보가 없을 때 사용하는 비밀번호 최대 유효기간 (초 단위)
#   - 사용하지 않더라도 필수로 설정 필요
#
# default_expire_warning:
#   - 정책 정보가 없을 때 사용하는 만료 경고 발송 기준 (초 단위)
#   - 사용하지 않더라도 필수로 설정 필요
#
# 비밀번호 정책 적용 우선순위
# 1. 사용자별 정책 (pwdPolicySubentry)
# 2. 글로벌 정책 (default_policy_dn)
# 3. 정책 미존재 시 스크립트 기본값 사용
# default_policy_dn="cn=PPolicy,ou=Policies,dc=ldap,dc=example,dc=com"
default_max_age=15552000       # 6개월 (180일)
default_expire_warning=1296000 # 15일

## LDAP 검색 범위 설정
# - base : 지정된 DN만 조회
# - one  : 지정된 DN의 1단계 하위만 조회
# - sub  : 지정된 DN 이하 전체 트리 조회 (가장 많이 사용)
search_scope="sub"

# LDAP 검색 필터 및 바이너리 설정
search_base="ou=People,dc=example,dc=com"
search_filter="(&(uid=*)(objectClass=inetOrgPerson))"
ldap_search_bin="/usr/local/bin/ldapsearch"

# SMTP 기본 설정 (msmtp 패키지 설치 필요)
smtp_server="smtp.example.com"
smtp_port=587
smtp_use_tls=true
smtp_auth=true
smtp_user="user@example.com"
smtp_pass="YourEmailPassword"

# 수/발신인 설정
mail_sender="admin@example.com"
report_recipient="admin@example.com"

# 회사 및 공통 설정
company_name="ExampleCorp"
company_team="${company_name} IT Team"
company_portal_url="https://portal.example.com"
mail_subject_prefix="[${company_name}]"

# 리포트 상세 로그 변수
declare report_detail=""
declare -i total_users=0
declare -i total_expired=0
declare -i total_warnings=0

# epoch 초(second) 변환
epoch() {
    date -d "${1}" +%s
}

# LDAP 옵션 생성 함수
build_ldap_options() {
    local options=(-LLL -H "${ldap_uri}" -x -D "${ldap_bind_dn}" -w "${ldap_bind_pw}")

    if [[ "${use_starttls}" == true ]]; then
        options+=(-ZZ)
    fi

    if [[ "${ldap_uri}" == ldaps* || "${use_starttls}" == true ]]; then
        if [[ "${use_tls_verify}" == true ]]; then
            options+=(-o TLS_CACERT="${tls_cacert_path}")
        else
            options+=(-o TLS_REQCERT=never)
        fi
    fi

    echo "${options[@]}"
}

# mail_command 생성 함수
build_mail_command() {
    local cmd="msmtp -f ${mail_sender} --host=${smtp_server} --port=${smtp_port}"

    if [[ "${smtp_use_tls}" == true ]]; then
        cmd+=" --tls=on"
    else
        cmd+=" --tls=off"
    fi

    if [[ "${smtp_auth}" == true ]]; then
        cmd+=" --auth=on --user=${smtp_user} --passwordeval='echo ${smtp_pass}'"
    else
        cmd+=" --auth=off"
    fi

    echo "${cmd}"
}

# LDAP 사용자 조회
fetch_ldap_users() {
    local ldap_options
    read -r -a ldap_options <<< "$(build_ldap_options)"

    "${ldap_search_bin}" "${ldap_options[@]}" \
        -s "${search_scope}" \
        -b "${search_base}" \
        "${search_filter}" dn |
    awk '/^dn: /{print $2}'
}

# 사용자 비밀번호 만료 여부 확인
check_password_expiry() {
    local dn=$1
    total_users+=1

    local ldap_options
    read -r -a ldap_options <<< "$(build_ldap_options)"

    # 사용자 기본 정보 조회
    local attrs
    attrs=$( "${ldap_search_bin}" "${ldap_options[@]}" \
        -s base -b "${dn}" \
        cn uid mail pwdChangedTime pwdPolicySubentry )

    local user_login user_name user_mail pwd_changed pwd_policy_dn
    user_login=$(echo "${attrs}" | awk '/^uid:/{print $2}')
    user_name=$(echo "${attrs}" | awk '/^cn:/{print substr($0, index($0,$2))}')
    user_mail=$(echo "${attrs}" | awk '/^mail:/{print $2}')
    pwd_changed=$(echo "${attrs}" | awk '/^pwdChangedTime:/{print substr($2,1,14)}')
    pwd_policy_dn=$(echo "${attrs}" | awk '/^pwdPolicySubentry:/{print $2}')

    # 비밀번호 정책 조회
    local policy_attrs pwd_max_age pwd_warning
    pwd_max_age=""
    pwd_warning=""

    if [[ -n "${pwd_policy_dn}" ]]; then
        policy_attrs=$( "${ldap_search_bin}" "${ldap_options[@]}" \
            -s base -b "${pwd_policy_dn}" pwdMaxAge pwdExpireWarning )
    elif [[ -n "${default_policy_dn}" ]]; then
        policy_attrs=$( "${ldap_search_bin}" "${ldap_options[@]}" \
            -s base -b "${default_policy_dn}" pwdMaxAge pwdExpireWarning )
    fi

    if [[ -n "${policy_attrs}" ]]; then
        pwd_max_age=$(echo "${policy_attrs}" | awk '/^pwdMaxAge:/{print $2}')
        pwd_warning=$(echo "${policy_attrs}" | awk '/^pwdExpireWarning:/{print $2}')
    fi

    # 누락 대비: 기본값 보장
    if [[ -z "${pwd_max_age}" ]]; then
        pwd_max_age="${default_max_age}"
    fi
    if [[ -z "${pwd_warning}" ]]; then
        pwd_warning="${default_expire_warning}"
    fi

    # 변경일자 없음 처리
    if [[ -z "${pwd_changed}" ]]; then
        report_detail+="No password change date: ${user_login}"$'\n'
        return
    fi

    # 변경일 → epoch
    local date_part time_part changed_date
    date_part="${pwd_changed:0:4}-${pwd_changed:4:2}-${pwd_changed:6:2}"
    time_part="${pwd_changed:8:2}:${pwd_changed:10:2}:${pwd_changed:12:2}"
    changed_date="${date_part} ${time_part}"

    local changed_epoch current_epoch expire_epoch diff
    changed_epoch=$(epoch "${changed_date}")
    current_epoch=$(date +%s)
    expire_epoch=$((changed_epoch + pwd_max_age))
    diff=$((expire_epoch - current_epoch))

    # 만료된 경우
    if (( diff <= 0 )); then
        total_expired+=1
        local expire_date
        expire_date="$(date -d "@${expire_epoch}" '+%Y-%m-%d %H:%M:%S')"
        report_detail+="Expired: ${user_login} - expired on ${expire_date}\n"
        return
    fi

    # 만료 임박 경고
    if (( diff <= pwd_warning )); then
        local days_left=$((diff / 86400))
        send_warning_if_needed "${user_name}" "${user_mail}" "${user_login}" \
            "${days_left}" "${expire_epoch}"
    fi
}

# 경고 메일 발송 처리
send_warning_if_needed() {
    local name=$1 mail=$2 login=$3 days_left=$4 expire_epoch=$5

    local expire_date
    expire_date="$(date -d "@${expire_epoch}" '+%Y-%m-%d %H:%M:%S')"

    send_expiry_mail "${name}" "${mail}" "${days_left}" "${expire_date}"

    total_warnings+=1
    report_detail+="Warning sent: ${login} (${mail}) - expires in ${days_left} days (on ${expire_date})"$'\n'
}

# 사용자에게 메일 발송
send_expiry_mail() {
    local name=$1 mail=$2 days_left=$3 expire_date=$4

    local mail_subject="${mail_subject_prefix} LDAP Password is Expiring Soon"

    mail_command=$(build_mail_command)
    
    {
        echo "Subject: ${mail_subject}"
        echo "From: ${mail_sender}"
        echo "To: ${mail}"
        echo ""
        echo "Hi ${name},"
        echo ""
        echo "Your LDAP password will expire in ${days_left} days (on ${expire_date})."
        echo ""
        echo "Update your password here: ${company_portal_url}"
        echo ""
        echo "For assistance, contact ${mail_sender}."
        echo ""
        echo "- ${company_team}"
    } | ${mail_command} "${mail}"
}

# 관리자에게 리포트 메일 발송
send_admin_report() {
    local mail_subject="${mail_subject_prefix} LDAP Password Expiration Report"

    mail_command=$(build_mail_command)

    {
        echo "Subject: ${mail_subject}"
        echo "From: ${mail_sender}"
        echo "To: ${report_recipient}"
        echo ""
        echo "LDAP Password Expiration Report"
        echo ""
        echo "Total Users Checked : ${total_users}"
        echo "Expired Accounts    : ${total_expired}"
        echo "Warnings Sent       : ${total_warnings}"

        if [[ -n "${report_detail}" ]]; then
            echo ""
            echo "Details:"
            printf "%b" "${report_detail}"
        fi
    } | ${mail_command} "${report_recipient}"
}

# 메인 실행 함수
main() {
    while IFS= read -r dn; do
        check_password_expiry "${dn}"
    done < <(fetch_ldap_users)

    send_admin_report
}

main "$@"
