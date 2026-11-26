# CI/CD 구성

개인 fork 저장소 기준으로 구축한 PillMate CI/CD 파이프라인 정리.

## 구성

```
push / PR ──(webhook)──> Jenkins (GCP VM, Docker 컨테이너)
                           1. Checkout
                           2. Build image
                           3. Test image (npm test)
                           4. Push image  -> Docker Hub   (develop, main)
                           5. Deploy      -> GKE          (main)
```

- Jenkins: Multibranch Pipeline, 브랜치별로 Jenkinsfile 실행
- feature 브랜치 / PR: 빌드 + 테스트만
- develop: 이미지 push (`develop` 태그)
- main: 이미지 push (`latest` 태그) + GKE 배포

| 파일 | 내용 |
| --- | --- |
| `Dockerfile` | 앱 이미지 (multi-stage, node 사용자로 실행) |
| `scripts/check-syntax.js` | `npm test`, 전체 js 문법 검사 |
| `Jenkinsfile` | 파이프라인 |
| `k8s/app.yaml` | 웹 Deployment + LoadBalancer Service |
| `k8s/mysql.yaml` | MySQL Deployment + PVC + ClusterIP Service |
| `k8s/ingress.yaml` | HTTPS Ingress, Google 관리형 인증서, 헬스체크 설정 |
| `jenkins/` | gcloud, kubectl, 플러그인 포함된 Jenkins 이미지 |
| `scripts/gcp/` | GCP 리소스 생성, Jenkins 설치, 클러스터 초기 설정, 삭제 |

## 구축 순서

### 1. GCP 리소스 (Cloud Shell)

```bash
git clone https://github.com/<user>/PillMate-2026.git && cd PillMate-2026
bash scripts/gcp/01-gcp-setup.sh <PROJECT_ID>
```

API 활성화, Jenkins VM + 고정 IP + 방화벽(8080, GitHub webhook IP 대역만 허용), GKE 클러스터(노드 1개), 배포용 서비스 계정(`jenkins-gke`, `roles/container.developer`)과 JSON 키 생성.

### 2. Jenkins 설치 (Jenkins VM)

```bash
gcloud compute ssh jenkins-server --zone asia-northeast3-a
curl -fsSL https://raw.githubusercontent.com/<user>/PillMate-2026/<branch>/scripts/gcp/02-jenkins-vm-setup.sh -o setup.sh
bash setup.sh <user> <branch>
```

8080은 외부에서 바로 열리지 않아서 SSH 터널로 접속 (Cloud Shell이면 웹 미리보기 8080).

```bash
gcloud compute ssh jenkins-server --zone asia-northeast3-a -- -L 8080:localhost:8080
```

`localhost:8080` 접속 → 초기 비밀번호 입력 → suggested plugins 설치 → 관리자 계정 생성.

### 3. 클러스터 초기 설정 (Cloud Shell)

```bash
cp .env.example .env.k8s   # 값 입력 + DB_ROOT_PASSWORD 추가
bash scripts/gcp/03-k8s-bootstrap.sh <PROJECT_ID> .env.k8s
```

- `.env.k8s` 내용은 Secret `pillmate-env`로 들어감 (git에는 안 올림)
- `db/*.sql`은 ConfigMap으로 만들어 MySQL 최초 기동 시 자동 실행
- API 키 변경 시 Secret만 다시 적용

```bash
kubectl create secret generic pillmate-env --from-env-file=.env.k8s --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/pillmate-web
```

### 4. Jenkins 설정

Credentials (Global)

| ID | 종류 | 값 |
| --- | --- | --- |
| `dockerhub` | Username with password | Docker Hub ID / access token (Read & Write) |
| `gke` | Google Service Account from private key | 프로젝트 ID / `jenkins-gke-key.json` |

Multibranch Pipeline
- Branch Source: GitHub, `https://github.com/<user>/PillMate-2026`
- Script Path: `Jenkinsfile`

GitHub Webhook (fork 저장소 Settings > Webhooks)
- Payload URL: `http://<VM IP>:8080/github-webhook/`
- Content type: `application/json`
- 이벤트: push, pull request
- 방화벽이 GitHub webhook 대역만 허용하므로 Payload URL은 VM IP 그대로 사용, 관리 화면만 터널로 접속

### 5. HTTPS

```bash
gcloud compute addresses create pillmate-ingress-ip --global
```

- duckdns에서 도메인을 위 IP로 변경
- `k8s/ingress.yaml`이 main 배포 때 같이 적용됨, 인증서 발급까지 15~60분
- OAuth 클라이언트 리디렉션 URI: `https://pillmate2026.duckdns.org/auth/google/callback`

### 6. 확인

```bash
kubectl get pods
kubectl get svc pillmate-web   # EXTERNAL-IP로 접속
```

## 트러블슈팅

| 문제 | 원인 | 해결 |
| --- | --- | --- |
| 강의 자료의 `jenkins/jenkins:lts-jdk11` 사용 시 플러그인 설치 문제 가능 | Jenkins LTS가 Java 11 지원 종료 | `lts-jdk21` 사용 |
| `apt.kubernetes.io`로 kubectl 설치 실패 | 해당 저장소 폐쇄(2024.03) | Google Cloud apt 저장소의 `kubectl` 설치 |
| 첫 CI 실행에서 `tools/csv-to-seed.js` 문법 오류 | 파일 앞뒤에 마크다운 코드블록 표시가 섞여 있었음 | 해당 줄 삭제 |
| 파드 여러 개일 때 로그인 풀림, 알림 중복 | express-session MemoryStore, node-cron이 파드마다 실행 | replicas 1 유지 (세션 저장소 분리는 추후 과제) |
| ConfigMap `kubectl apply` 실패 | seed sql이 커서 annotation 크기 제한(256KB) 초과 | delete 후 `kubectl create` |
| Jenkins 브랜치 스캔이 5분씩 대기 | GitHub API 익명 접근 + 기본 rate limit 전략(Normalize) | Jenkins 설정에서 `Throttle at/near rate limit`으로 변경 |
| fork 시 develop 브랜치만 복사됨 | fork 화면의 기본 브랜치만 복사 옵션 | main 브랜치 별도로 push |
| `GOOGLE_CLIENT_ID` 비어 있으면 서버 시작 실패 | passport GoogleStrategy가 clientID 필수 | 값이 없을 땐 임시값 사용 |
| 브랜치마다 이미지 태그가 겹침 (`develop` 1번과 `main` 1번이 둘 다 `:1`) | 태그를 BUILD_ID로만 생성 | 태그를 `<브랜치>-<빌드번호>`로 변경 |
| 구글 로그인 `400 invalid_request` | Google OAuth는 IP 주소, http 리디렉션 URI를 허용하지 않음 | duckdns 도메인 + Ingress(관리형 인증서)로 https 적용, `trust proxy` / passport `proxy: true` 설정 |
| Ingress 헬스체크 실패 가능성 | `/`가 로그인 페이지로 302 응답 | BackendConfig로 헬스체크 경로를 `/auth/login`으로 지정 |
| 기존 OAuth 클라이언트 수정 불가 | 만든 사람의 GCP 프로젝트에 있음 | 새 프로젝트에서 OAuth 클라이언트 재발급 |
| MySQL 8에서 `[Migration] ... 실패` 로그 | `ADD COLUMN IF NOT EXISTS`는 MariaDB 문법 | schema.sql에 컬럼이 이미 있어서 동작에는 영향 없음 |
| Jenkins 관리자 비밀번호, Credential이 HTTP로 전송됨 | 8080을 0.0.0.0/0으로 열고 브라우저로 바로 접속 | 8080은 GitHub webhook IP 대역만 허용, 관리 화면은 SSH 터널로 접속 |
| 팀 공용 Jenkins의 8080을 막았더니 개인 Jenkins webhook도 같이 막힘 | 같은 GCP 프로젝트에서 두 VM이 같은 방화벽 규칙(`allow-jenkins-8080`, 태그 `jenkins`)을 사용 | 개인 VM에 전용 태그(`personal-jenkins`)와 전용 규칙(`allow-personal-jenkins-webhook`)을 따로 둠 |

## 기타

- 챗봇(Ollama)은 클러스터에 없어서 챗봇 기능은 동작하지 않음
- 카카오맵은 개발자 콘솔에 배포 주소(IP)를 Web 도메인으로 등록해야 표시됨
- MySQL 초기 SQL은 PVC가 비어 있을 때만 실행됨
- 삭제: `bash scripts/gcp/99-cleanup.sh <PROJECT_ID>`
