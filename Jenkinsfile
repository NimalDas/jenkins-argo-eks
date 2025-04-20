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
                        echo "Pushing Node.js container image to ECR using Podman and IRSA..."
                        script {
                            // Authenticate Podman to ECR using AWS CLI and IRSA
                            // This command uses the credentials provided by the Service Account's assumed role
                            sh "aws ecr get-login-password --region ${env.AWS_REGION} | podman login --username AWS --password-stdin ${env.ECR_REGISTRY}"
                            echo "Podman login to ECR successful using IRSA."

                            // Define the full image name with the tag from the build stage
                            def fullImageNameWithTag = "${env.ECR_REGISTRY}:${env.VERSION}" 

                            // Tag the image for ECR using the full registry path and tag
                            // You are already building with the full name and tag, so retagging might be redundant
                            // unless you specifically need the 'latest' tag.
                            // If you want 'latest', you can tag the specific version image with 'latest'
                            sh "sudo podman tag ${fullImageNameWithTag} ${env.ECR_REGISTRY}:latest"

                            // Push the built Node.js image (specific version tag)
                            sh "sudo podman push ${fullImageNameWithTag}"
                            echo "Node.js container image pushed to ECR: ${fullImageNameWithTag}"

                            // Push the 'latest' tag 
                            sh "sudo podman push ${env.ECR_REGISTRY}:latest"
                            echo "'latest' tag pushed to ECR."
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