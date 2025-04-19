pipeline {
    agent any 

    environment {
        GIT_CREDENTIAL_ID = "jenkins-argo-eks-repo-creds"
        REPO_SSH_URL = "git@github.com:NimalDas/jenkins-argo-eks.git" // Your SSH URL
    }

    stages {
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
                    // --- Use sshagent to make the SSH key available for git push ---
                    sshagent([env.GIT_CREDENTIAL_ID]) {
                        echo "Setting origin remote URL to SSH: ${env.REPO_SSH_URL}"
                        sh "git remote set-url origin ${env.REPO_SSH_URL}"
                        sh 'git remote -v' // Optional: Verify the remote URL is updated

                        // Create or update a dummy file with a timestamp
                        sh 'date > test-pipeline-status.txt'
                        sh 'echo "Pipeline build number: ${BUILD_NUMBER}" >> test-pipeline-status.txt'

                        // Configure Git identity for the commit
                        sh 'git config user.email "jenkins@nimaldas.com"'
                        sh 'git config user.name "Jenkins Pipeline Test"'

                        // Add the file to staging
                        sh 'git add test-pipeline-status.txt'

                        // Commit the changes
                        sh 'git commit -m "Test commit from Jenkins Pipeline Build #${BUILD_NUMBER}"'

                        // Push the changes back to the repository
                        echo "Pushing changes back to origin..."
                        // This git push command should now use the SSH key via the sshagent
                        sh 'git push origin HEAD'

                        echo "Push complete."
                    } // --- End of sshagent block ---
                }
            }
        }
    }
    post {
        always {
            echo "Pipeline finished. Check your Git repository for 'test-pipeline-status.txt'."
        }
    }
}