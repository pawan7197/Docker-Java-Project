# End-to-End CI/CD Pipeline: GitHub → SonarQube → Maven → Nexus → Docker Hub → Jenkins

## Project Overview

This project implements a fully automated CI/CD pipeline for Java projects. Once code is pushed to GitHub, the pipeline performs the following steps:

- Clone the latest code from GitHub.
- Perform static code analysis using SonarQube.
- Build the project using Maven (including running unit tests).
- Upload the generated artifact (JAR/WAR) to Nexus Repository Manager.
- Build a Docker image containing the artifact.
- Push the Docker image to Docker Hub.
- Orchestrate all stages via a Jenkins declarative pipeline.

This pipeline ensures:

- Code quality enforcement via SonarQube.
- Versioned artifact management via Nexus.
- Containerized deployable artifacts via Docker.
- Traceability from Git commit → build → artifact → Docker image.
- Automated notifications for success/failure.

---

## Objectives

1. Fully automated pipeline requiring no manual intervention post code push.
2. Ensure code quality, versioning, and traceability.
3. Provide a reusable, scalable infrastructure for future Java projects.
4. Transparent logging, metrics, and notifications for stakeholders.

---

## Stakeholders

- **Development Team:** Pushes code to GitHub.
- **DevOps Team:** Implements and maintains the CI/CD pipeline.
- **QA Team:** Validates quality criteria and test coverage.
- **Security Team:** Ensures secure handling of credentials and pipeline best practices.
- **Project Manager:** Monitors pipeline delivery and effectiveness.

---

## Functional Requirements

### 1. GitHub Integration

- Repository hosted on GitHub.
- Webhook triggers Jenkins pipeline on pushes to `main` or `develop` branch.
- Capture Git commit hash for traceability.

### 2. SonarQube Integration

- Run SonarQube Scanner using Maven plugin.
- Enforce a Quality Gate:
  - Minimum code coverage: **80%**
  - No new critical vulnerabilities or blockers
  - Maximum allowed code duplication or code smells (as defined by your org gate)
- Pipeline stops and notifies stakeholders if Quality Gate fails.

### 3. Maven Build

- Build using Maven: `mvn clean install` (or `mvn clean verify` in pipeline)
- Run unit tests: `mvn test`
- Artifact output: JAR/WAR
- Version artifact using Git commit hash or Maven version.

### 4. Artifact Management (Nexus)

- Upload artifact to Nexus repository.
- Manage credentials securely via Jenkins Credentials Store.
- Ensure artifact is retrievable for Docker build.

### 5. Docker Image Creation

- Dockerfile present in repository.
- Docker image includes Maven-built artifact.
- Image tagged using version/commit hash (e.g., `myapp:1.0.0-ab12cd3`).

### 6. Push Docker Image to Docker Hub

- Authenticate Jenkins to Docker Hub via credentials.
- Push image using `docker push`.
- Image available for downstream deployments.

### 7. Jenkins Pipeline

- Declarative `Jenkinsfile` defines the pipeline stages:
  - Checkout
  - SonarQube Analysis
  - Build (Maven)
  - Upload Artifact to Nexus
  - Build Docker Image
  - Push Docker Image

---

## Technical Specifications

- **GitHub:** Repository URL, branch monitored, webhook configured.
- **SonarQube:** Version 8.x+, quality gate defined, API token in Jenkins.
- **Maven:** Version 3.6+, commands: `mvn clean test package`.
- **Nexus:** Version 3.x, artifact repository, retention policy.
- **Docker & Docker Hub:** Docker runtime 20.x+, image tagging using commit hash.
- **Jenkins:** LTS 2.x, required plugins (Git, Pipeline, Maven, Docker, SonarQube, Credentials, Slack/Email).

---

## Example Declarative Jenkinsfile

```groovy
pipeline {
    agent any

    tools {
        jdk 'JDK'
        maven 'MAVEN'
    }

    environment {
        JAVA_HOME = tool name: 'JDK', type: 'jdk'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
        DOCKER_IMAGE = "udaysairam/java-webapp:${env.BUILD_NUMBER}"
        MAVEN_SETTINGS = "temp-settings.xml"
        SONAR_HOST = "http://34.201.99.100:9000"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/uday79936/Java-Web-Calculator-App.git'
            }
        }

        stage('Build with Maven') {
            steps {
                echo "Running Maven build..."
                sh 'mvn clean verify -B'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "Running SonarQube analysis..."
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh """
                        mvn sonar:sonar -B \
                          -Dsonar.projectKey=java-webapp-region \
                          -Dsonar.host.url=${SONAR_HOST} \
                          -Dsonar.login=\$SONAR_TOKEN
                    """
                }
            }
        }

        stage('Deploy to Nexus') {
            steps {
                echo "Deploying artifact to Nexus..."
                writeFile file: "${MAVEN_SETTINGS}", text: """
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
  <servers>
    <server>
      <id>maven-releases</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
  </servers>
</settings>
"""
                sh """
                    mvn deploy -B -s ${MAVEN_SETTINGS} \
                      -DaltDeploymentRepository=maven-releases::default::http://34.201.99.100:8081/repository/maven-releases/
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${DOCKER_IMAGE}"
                sh """
                    docker build -t ${DOCKER_IMAGE} .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo "Pushing Docker image to Docker Hub: ${DOCKER_IMAGE}"
                withCredentials([usernamePassword(credentialsId: 'docker_hub', usernameVariable: 'DOCKER_HUB_USR', passwordVariable: 'DOCKER_HUB_PSW')]) {
                    sh """
                        echo \$DOCKER_HUB_PSW | docker login -u \$DOCKER_HUB_USR --password-stdin
                        docker push ${DOCKER_IMAGE}
                    """
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                echo "Deploying Docker container for Tomcat..."
                sh """
                    docker stop TOMCAT || true
                    docker rm TOMCAT || true
                    docker run -d --name TOMCAT -p 8501:8080 ${DOCKER_IMAGE}
                """
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
            sh 'rm -f ${MAVEN_SETTINGS}'
        }
        success {
            echo "Pipeline succeeded! All steps completed."
        }
        failure {
            echo "Pipeline failed! Check logs for details."
        }
    }
}
```

---

## Milestones & Timeline (Estimates)

| Milestone | Duration | Description |
|---|---:|---|
| GitHub Webhook & Jenkins | 2–3 days | Configure repository, webhook, basic job |
| SonarQube Integration | 3–4 days | Setup server, plugin, quality gate |
| Maven Build Setup | 2–3 days | Build project, run unit tests |
| Nexus Integration | 2 days | Configure repository, upload artifact |
| Docker Image Build & Push | 3–4 days | Create Dockerfile, build, push image |
| Full Pipeline Orchestration | 2–3 days | Combine all steps in Jenkinsfile |
| Testing & QA | 3–4 days | End-to-end pipeline testing |
| Documentation & Handoff | 1–2 days | Final documentation |

---

## Deliverables

1. `Jenkinsfile` implementing full pipeline.
2. Sample Maven project with `Dockerfile`.
3. Documentation: setup steps, screenshots, pipeline explanation.
4. Nexus and Docker Hub configurations.

---

## How to Use This Repository

1. Clone the repository:
```bash
git clone <repo-url>
```
2. Push code to GitHub (`main`/`develop` branch) to trigger pipeline.
3. Monitor Jenkins job for build, SonarQube analysis, artifact upload, Docker image build and push.
4. Check SonarQube dashboard for code quality.
5. Verify artifact in Nexus and Docker image in Docker Hub.

---
## IMAGES

<img width="1920" height="1080" alt="1" src="https://github.com/user-attachments/assets/1ca10294-5e6c-43e3-a8cb-78b820a82e3f" />

<img width="1920" height="1080" alt="2" src="https://github.com/user-attachments/assets/f33192ee-9e96-47c6-bee3-4f2e2c8e7682" />

<img width="1920" height="1080" alt="3" src="https://github.com/user-attachments/assets/e62e464a-3cb1-438d-9721-d5f2925cf22c" />

<img width="1920" height="1080" alt="4" src="https://github.com/user-attachments/assets/cfdb5ae4-cc8a-45b2-bf3f-ae8aefec0f86" />

<img width="927" height="166" alt="5" src="https://github.com/user-attachments/assets/c8535ed3-0474-4216-bccd-ba3e0fb22b11" />

<img width="848" height="367" alt="6" src="https://github.com/user-attachments/assets/647b72df-630b-46f8-ad2c-ab2437ab8ae3" />

<img width="1920" height="1080" alt="7" src="https://github.com/user-attachments/assets/e6e7106b-49b5-4433-82c9-824e41f294ec" />

<img width="823" height="411" alt="8" src="https://github.com/user-attachments/assets/55cd40f8-8cd5-4e4e-ad14-404e32c17dfe" />

<img width="819" height="368" alt="9" src="https://github.com/user-attachments/assets/cb31ba5d-e31e-4864-89af-d835ecd61da1" />

<img width="825" height="438" alt="10" src="https://github.com/user-attachments/assets/f7b2e06e-96e0-43cd-87cb-b8b921f1809d" />

<img width="875" height="207" alt="11" src="https://github.com/user-attachments/assets/6f4c3aa5-62be-4fb6-8833-9b0d897bee28" />

<img width="768" height="301" alt="12" src="https://github.com/user-attachments/assets/d6f83151-5a29-40f5-ac99-d0d089cc5f9b" />

<img width="925" height="378" alt="13" src="https://github.com/user-attachments/assets/49ebe97f-503e-477e-bfba-8bd41244aea8" />

<img width="814" height="443" alt="14" src="https://github.com/user-attachments/assets/e1906060-83a6-4c22-82bd-a17f47eaa1b7" />

<img width="856" height="296" alt="15" src="https://github.com/user-attachments/assets/28a70549-8a27-4aad-91f1-565316df7d74" />

<img width="896" height="237" alt="16" src="https://github.com/user-attachments/assets/ea7af3f7-4664-424e-92df-cb9a54b74b25" />

<img width="1920" height="1080" alt="17" src="https://github.com/user-attachments/assets/94131848-d2dd-4f48-98ab-b9077b43aff3" />

<img width="1920" height="1080" alt="18" src="https://github.com/user-attachments/assets/46f4a1aa-d74c-4f8c-8f74-cf9d8f6988f3" />

<img width="1920" height="1080" alt="19" src="https://github.com/user-attachments/assets/7c994224-787f-4eef-9942-7f274d297e41" />

<img width="1920" height="1080" alt="20" src="https://github.com/user-attachments/assets/c4db7f98-4c8a-4e51-b0f8-1af996d45296" />

<img width="1920" height="1080" alt="21" src="https://github.com/user-attachments/assets/8b37241d-2141-4747-80e3-67a41680d271" />

<img width="1920" height="1080" alt="22" src="https://github.com/user-attachments/assets/b89d6ca5-fa57-4c7a-aaca-e17a8ba43ce3" />

<img width="1920" height="1080" alt="23" src="https://github.com/user-attachments/assets/91fc6e25-c99a-4eb6-8d19-770c4f390d73" />

<img width="1920" height="1080" alt="24" src="https://github.com/user-attachments/assets/7246ca95-a27c-4092-a703-97089985508a" />

<img width="1920" height="1080" alt="25" src="https://github.com/user-attachments/assets/8aa3f8cf-8276-494c-8adc-f4f767dd2dee" />

<img width="1920" height="1080" alt="26" src="https://github.com/user-attachments/assets/bca3debf-63fb-42ca-8c40-2180064fede2" />

<img width="1920" height="1080" alt="27" src="https://github.com/user-attachments/assets/f32d1c59-6f50-4c4d-9831-b3160d7a0e9f" />

<img width="1594" height="688" alt="28" src="https://github.com/user-attachments/assets/e2cb9803-02f3-4f29-a912-6218f8d07229" />

<img width="1920" height="1080" alt="29" src="https://github.com/user-attachments/assets/44d8d01d-76aa-4e1a-8031-9d6b2412a547" />


<img width="1596" height="774" alt="docker-output" src="https://github.com/user-attachments/assets/522cedf6-daa8-4730-b609-ee084c257f84" />
























































