# LDAP Password Expiration Notification Script

이 스크립트는 LDAP 사용자들의 비밀번호 만료를 사전에 알려주고, 관리자에게 전체 리포트를 발송하는 자동화 도구입니다.

## 주요 기능

- LDAP 사용자 비밀번호 만료일 자동 체크
- 만료 임박 사용자에게 이메일 알림 발송
- 관리자에게 일일 리포트 메일 전송
- TLS/StartTLS 및 SMTP 인증 지원
- 다양한 환경에 맞게 설정 가능 (템플릿 형태)

---

## 환경 요구사항

- Linux 기반 시스템 (테스트: Rocky Linux 9.5, OpenSUSE 15.6)
- 필수 패키지:
  - `msmtp`
  - `ldap-utils` 또는 호환 ldapsearch 바이너리

## 설치 방법

### 패키지 설치 (예시: RHEL 계열)

```bash
dnf install msmtp openldap-clients
```

>  *EPEL 리포지토리 필요할 수 있음*

---

## 설정 방법

스크립트 상단의 변수를 환경에 맞게 수정하세요.

### 1. LDAP 설정

```bash
ldap_uri="ldap://ldap.example.com:389"
ldap_bind_dn="cn=binduser,ou=Users,dc=ldap,dc=example,dc=com"
ldap_bind_pw="YourSecretPassword"
use_starttls=false
use_tls_verify=false
tls_cacert_path="/etc/ssl/certs/ca-bundle.crt"
```

### 2. 비밀번호 정책 설정

```bash
default_policy_dn="cn=PPolicy,ou=Policies,dc=ldap,dc=example,dc=com"
default_max_age=15552000       # 6개월
default_expire_warning=1296000 # 15일
```

### 3. 검색 범위 및 필터

```bash
search_scope="sub"
search_base="ou=People,dc=example,dc=com"
search_filter="(&(uid=*)(objectClass=inetOrgPerson))"
ldap_search_bin="/usr/local/bin/ldapsearch"
```

### 4. SMTP 설정 (msmtp 필수)

```bash
smtp_server="smtp.example.com"
smtp_port=587
smtp_use_tls=true
smtp_auth=true
smtp_user="user@example.com"
smtp_pass="YourEmailPassword"
```

### 5. 회사 및 메일 설정

```bash
mail_sender="admin@example.com"
report_recipient="admin@example.com"

company_name="ExampleCorp"
company_team="${company_name} IT Team"
company_portal_url="https://portal.example.com"
mail_subject_prefix="[${company_name}]"
```

---

## 실행 방법

### 수동 실행

```bash
bash ldap_password_notify.sh
```

### 크론탭 등록 예시 (매일 9시 실행)

```bash
0 9 * * * /path/to/ldap_password_notify.sh >/dev/null 2>&1
```

---

## 이메일 예시

### 사용자 알림 메일

```
Subject: [ExampleCorp] LDAP Password is Expiring Soon

Hi John Doe,

Your LDAP password will expire in 5 days (on 2024-05-03).

Update your password here: https://portal.example.com

For assistance, contact admin@example.com.

- ExampleCorp IT Team
```

### 관리자 리포트 메일

```
Subject: [ExampleCorp] LDAP Password Expiration Report

LDAP Password Expiration Report

Total Users Checked: 50
Expired Accounts: 3
Warnings Sent: 5

Details:
Expired: user1
Warning sent: user2 (user2@example.com)
...
```

---

## 기타

- 스크립트 내 **계정정보/비밀번호**는 반드시 접근 권한을 제한하세요 (`chmod 700`).
- `msmtp` 설정은 서버 환경에 따라 추가적인 설정파일이 필요할 수 있습니다.
- LDAP 서버 정책에 따라 `pwdChangedTime` 수정이 제한될 수 있습니다.
- 검색 필터와 Base DN은 반드시 환경에 맞게 조정하세요.

---

## 라이선스

This project is licensed under the **Beerware License (Revision 42)**.

As long as you retain the license notice, you can do whatever you want with this script.  
If we meet someday and you think it's useful, buy me a beer! 🍺
