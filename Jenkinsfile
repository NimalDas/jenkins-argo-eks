// Jenkinsfile at the root of your jenkins-argo-eks repo

pipeline {
    agent any

    environment {
        GIT_CREDENTIAL_ID = "jenkins-argo-eks-repo-creds"
        REPO_SSH_URL = "git@github.com:NimalDas/jenkins-argo-eks.git" 
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
                // Ensure the .ssh directory exists
                sh 'mkdir -p ~/.ssh'
                // Scan for github.com host key and add it to known_hosts
                sh 'ssh-keyscan github.com >> ~/.ssh/known_hosts'
                sh 'echo "github.com host key added."'
            }
        }
        stage('Checkout Repository') {
            steps {
                echo "Checking out repository ${env.REPO_SSH_URL} using credential ID ${env.GIT_CREDENTIAL_ID}"
                git url: env.REPO_SSH_URL, branch: 'main', credentialsId: env.GIT_CREDENTIAL_ID
                echo "Checkout complete. Workspace content:"
                sh 'ls -a'
                sh 'pwd'
            }
        }

        stage('Add or Update File and Push') {
            steps {
                echo "Adding or updating a test file and pushing changes..."
                script {
                    sshagent([env.GIT_CREDENTIAL_ID]) {
                        echo "Setting origin remote URL to SSH: ${env.REPO_SSH_URL}"
                        sh "git remote set-url origin ${env.REPO_SSH_URL}"
                        sh 'git remote -v'

                        // Create or update a dummy file
                        sh 'date > test-pipeline-status.txt'
                        sh 'echo "Pipeline build number: ${BUILD_NUMBER}" >> test-pipeline-status.txt'

                        // Configure Git identity
                        sh 'git config user.email "jenkins@nimaldas.com"'
                        sh 'git config user.name "NimalDas"'

                        // Add file
                        sh 'git add test-pipeline-status.txt'

                        // Commit changes
                        sh 'git commit -m "Test commit from Jenkins Pipeline Build #${BUILD_NUMBER}"'

                        // Push changes
                        echo "Pushing changes back to origin..."
                        sh 'git push origin HEAD'

                        echo "Push complete."
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