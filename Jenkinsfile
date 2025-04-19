pipeline {
    agent any
    environment {
        GIT_CREDENTIAL_ID = "jenkins-argo-eks-repo-creds"
        REPO_SSH_URL = "git@github.com:NimalDas/jenkins-argo-eks.git"
        AWS_REGION = "us-east-1"
        ECR_REGISTRY = "965202785849.dkr.ecr.us-east-1.amazonaws.com/nodejs-app"
        IMAGE_NAME = "nodejs-app"
        VERSION = "${env.BUILD_NUMBER}"
    }
    stages {
        stage('Check for Podman') {
            steps {
                echo "Checking if podman is available..."
                sh 'podman --version || echo "Podman not found"'
            }
        }
        stage('Add GitHub Host Key') {
            steps {
                echo "Adding github.com host key to known_hosts..."
                sh 'mkdir -p ~/.ssh'
                sh 'ssh-keyscan github.com >> ~/.ssh/known_hosts'
                sh 'echo "github.com host key added."'
            }
        }
        stage('Checkout Repository') {
            steps {
                echo "Checking out repository ${env.REPO_SSH_URL}"
                git url: env.REPO_SSH_URL, branch: 'main', credentialsId: env.GIT_CREDENTIAL_ID
                sh 'ls -a'
                sh 'pwd'
            }
        }
        stage('Build Node.js App') {
            steps {
                dir('eks-gitops/nodejs-app') {
                    sh '''
                        npm install --production
                        npm run start & 
                        NODE_PID=$!
                        sleep 5 && curl -f http://localhost:3000 || exit 1
                        kill $NODE_PID
                    '''
                }
            }
        }
        stage('Build Docker Image with Podman') {
            steps {
                dir('eks-gitops/nodejs-app') {
                    sh 'sudo podman build -t ${ECR_REGISTRY}:${VERSION} .'
                }
            }
        }
        stage('Push to ECR') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                     #   aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_REGISTRY}
                        sudo podman tag ${ECR_REGISTRY}:${VERSION} ${ECR_REGISTRY}:latest
                        sudo podman push ${ECR_REGISTRY}:${VERSION}
                        sudo podman push ${ECR_REGISTRY}:latest
                    '''
                }
            }
        }
        stage('Update Manifest') {
            steps {
                dir('eks-gitops/nodejs-app/k8s') {
                    sshagent([env.GIT_CREDENTIAL_ID]) {
                        sh """
                            git remote set-url origin ${env.REPO_SSH_URL}
                            sed -i 's|image: ${ECR_REGISTRY}:.*|image: ${ECR_REGISTRY}:${VERSION}|' deployment.yaml
                            sed -i 's|value: \".*\"|value: \"v${VERSION}\"|' deployment.yaml
                            git config user.email 'jenkins@nimaldas.com'
                            git config user.name 'NimalDas'
                            git add deployment.yaml
                            git commit -m 'Update deployment to version ${VERSION}'
                            git push origin main
                        """
                    }
                }
            }
        }
    }
    post {
        always {
            echo "Pipeline finished."
        }
    }
}