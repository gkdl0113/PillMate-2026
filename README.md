# PILLMATE

가정 내 보유한 의약품을 디지털로 등록·관리하고, 유통기한을 자동으로 추적하며,
증상 입력 시 보유 의약품 정보를 제공하는 가정용 스마트 약장 관리 서비스

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| Backend | Node.js, Express.js |
| Frontend | EJS, Bootstrap 5, Vanilla JS |
| Database | MySQL 8.0 |
| 배포 | GCP (Cloud SQL + Compute Engine) |

---

## 로컬 실행 방법

### 1. 의존성 설치

```bash
npm install
```

### 2. 환경변수 설정

`.env.example`을 복사해 `.env` 파일을 생성하고 값을 채워주세요.

```bash
cp .env.example .env
```

`.env` 파일 항목 설명:

| 항목 | 설명 |
|------|------|
| `PORT` | 서버 포트 (기본값: 3000) |
| `DB_HOST` | MySQL 호스트 |
| `DB_PORT` | MySQL 포트 (기본값: 3306) |
| `DB_USER` | MySQL 사용자 이름 |
| `DB_PASSWORD` | MySQL 비밀번호 |
| `DB_NAME` | 사용할 데이터베이스 이름 |
| `SESSION_SECRET` | 세션 암호화 키 (임의 문자열) |

### 3. 서버 실행

개발 모드 (nodemon, 파일 변경 시 자동 재시작):
```bash
npm run dev
```

일반 실행:
```bash
npm start
```

또는:
```bash
node app.js
```

### 4. 브라우저 접속

```
http://localhost:3000
```

---

## 현재 개발 단계

현재는 **초기 실행 구조** 단계입니다.
Express 서버 기동 및 기본 화면 렌더링 확인을 목적으로 하며,
기능별 파일(auth, medicine, family, guide 등)은 추후 단계에서 추가할 예정입니다.

```
현재 구현 범위:
- app.js (서버 진입점)
- routes/indexRoutes.js (기본 라우트)
- views/index.ejs + partials (공통 레이아웃)
- public/css/style.css (커스텀 스타일 준비)
```
