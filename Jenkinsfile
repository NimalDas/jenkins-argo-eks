pipeline {
    agent any // You can specify a Kubernetes agent here if you have one configured

    environment {
        GIT_CREDENTIAL_ID = "jenkins-argo-eks-repo-creds"
        REPO_URL = "https://github.com/NimalDas/jenkins-argo-eks" // e.g., git@github.com:your-username/jenkins-argo-eks.git
    }

    stages {
        stage('Checkout Repository') {
            steps {
                echo "Checking out repository ${env.REPO_URL} using credential ID ${env.GIT_CREDENTIAL_ID}"
                git url: env.REPO_URL, branch: 'main', credentialsId: env.GIT_CREDENTIAL_ID
                echo "Checkout complete. Workspace content:"
                sh 'ls -a' // List all files, including hidden ones like .git
                sh 'pwd'  // Print working directory
            }
        }

        stage('Add or Update File and Push') {
            steps {
                echo "Adding or updating a test file and pushing changes..."
                script {
                    git url: env.REPO_URL, branch: 'main', credentialsId: env.GIT_CREDENTIAL_ID
                    // Create or update a dummy file with a timestamp
                    sh 'date > test-pipeline-status.txt'
                    sh 'echo "Pipeline build number: ${BUILD_NUMBER}" >> test-pipeline-status.txt'

                    // Configure Git identity for the commit
                    // sh 'git config user.email "jenkins@nimaldas.com"' // Replace with a suitable email
                    // sh 'git config user.name "Jenkins Pipeline Test"'

                    // Add the file to staging
                    sh 'git add test-pipeline-status.txt'

                    // Commit the changes
                    sh 'git commit -m "Test commit from Jenkins Pipeline Build #${BUILD_NUMBER}"'

                    // Push the changes back to the repository using the credential from the checkout
                    echo "Pushing changes back to origin..."
                    sh 'git push origin HEAD' // Push to the current branch (e.g., main)

                    echo "Push complete."
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