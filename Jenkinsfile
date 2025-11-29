pipeline {
    agent { label 'ec2-agent' }

    environment {
        IMAGE_NAME = "danielashkenazy1/cicd_k8s_python_app"
        KUBECONFIG = "/home/ubuntu/.kube/config"
    }

    stages {

        // ------------------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Verify PR Merge') {
            steps {
                script {
                    def msg = sh(
                        script: "git log -1 --pretty=%s",
                        returnStdout: true
                    ).trim()

                    if (!msg.startsWith("Merge pull request")) {
                        error "Pipeline aborted: this is NOT a PR merge."
                    }

                    echo "✔ Confirmed: PR merge detected, continuing pipeline..."
                }
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
                        filesystem /scan/Docker --fail --no-update \
                        --exclude-paths /scan/Jenkins/ci/trufflehog_exclude.txt
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
                    pip install -r requirments.txt
                    pip install flake8 
                    flake8 . --exclude=.venv,__pycache__,.git --ignore=E501,W292,E303,E302
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
                    bandit -r . -x .venv,tests,__pycache__,**/site-packages/** -ll --skip B104,B113
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

                    junit 'Docker/junit.xml'


                publishHTML(target: [
                    reportDir: 'Docker/htmlcov',
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
                        cd Docker
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
                        python-app ./Helm \
                        --namespace devops \
                        --set image.tag=${IMAGE_TAG}

                    """
                }
            }
        }

    } 
}