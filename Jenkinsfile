pipeline {
    agent { label 'linux' }

    environment {
        IMAGE_NAME = "danielashkenazy1/cicd_k8s_python_app"
    }

    stages {

        // ------------------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ------------------------------
        stage('Secrets Detection') {
            steps {
                script {
                    echo "Running secrets detection with TruffleHog..."

                    sh """
                    docker run --rm \
                        -v "\$(pwd):/scan" \
                        trufflesecurity/trufflehog:latest \
                        filesystem /scan --fail --no-update \
                        --exclude-paths /scan/shared/ci/trufflehog_exclude.txt
                    """
                }
            }
        }

        // ------------------------------
        stage('Lint') {
            steps {
                script {
                    sh """
                    cd Docker
                    echo "Running Flake8..."
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements.txt
                    pip install flake8
                    flake8 . --exclude=.venv,__pycache__,.git
                    """
                }
            }
        }

        // ------------------------------
        stage('Security Scan') {
            steps {
                script {
                    sh """
                    cd Docker
                    echo "Running Bandit..."
                    . .venv/bin/activate || true
                    pip install bandit
                    bandit -r app -x .venv,tests,__pycache__,**/site-packages/** -ll
                    """
                }
            }
        }

        // ------------------------------
        stage('Unit Tests') {
            steps {
                script {
                    sh """
                    cd Docker
                    echo "Running Pytest..."
                    . .venv/bin/activate
                    pip install pytest pytest-cov
                    pytest --cov=. --cov-report=html --cov-report=xml --junitxml=junit.xml
                    """
                }

                junit 'junit.xml'

                publishHTML(target: [
                    reportDir: 'htmlcov',
                    reportFiles: 'index.html',
                    reportName: "Coverage Report"
                ])
            }
        }

        // ------------------------------
        stage('Approve Deployment') {
            steps {
                script {
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            input(
                                id: 'deploy_confirm',
                                message: 'Deploy to Docker Hub and K8s?',
                                parameters: [
                                    [$class: 'BooleanParameterDefinition',
                                     defaultValue: true,
                                     name: 'Confirm']
                                ]
                            )
                        }
                    } catch (err) {
                        currentBuild.result = 'ABORTED'
                        error("Deployment cancelled by user")
                    }
                }
            }
        }

        // ------------------------------
        stage('Build & Push Docker Image') {
            steps {
                script {
                    def shortSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()

                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker build -t $IMAGE_NAME:ci-${shortSha} .
                        docker push $IMAGE_NAME:ci-${shortSha}
                        """
                    }

                    env.IMAGE_TAG = "ci-${shortSha}"
                }
            }
        }

        // ------------------------------
        stage('Deploy to Kubernetes (HELM)') {
            steps {
                script {

                    sh """
                    echo "Deploying with Helm..."

                    helm upgrade --install \
                        python-app ./helm \
                        --namespace devops \
                        --create-namespace \
                        --set image.tag=${IMAGE_TAG}

                    """
                }
            }
        }

    } 
}