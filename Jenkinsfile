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
        // stage('Check for Podman') {
        //     steps {
        //         echo "Checking if podman is available..."
        //         sh 'podman --version || echo "Podman not found"'
        //         sh 'aws --version || echo "awscli not found"'
        //     }
        // }
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
                    sh 'podman build -t ${ECR_REGISTRY}:${VERSION} .'
                }
            }
        }
        stage('Push to ECR') {
            steps {
                echo "Pushing Node.js container image to ECR using podman and IRSA"
                script {
                    // Authenticate podman to ECR using IRSA
                    sh "aws ecr get-login-password --region ${env.AWS_REGION} | podman login --username AWS --password-stdin ${env.ECR_REGISTRY}"
                    echo "Podman login to ECR successful using IRSA."

                    // Define the full image name with the tag from the build stage
                    def fullImageNameWithTag = "${env.ECR_REGISTRY}:${env.VERSION}"

                    // Tag the image for ECR using the full registry path and tag
                    sh "podman tag ${fullImageNameWithTag} ${env.ECR_REGISTRY}:latest"
                    sh "podman push ${fullImageNameWithTag}"
                    echo "Node.js container image pushed to ECR: ${fullImageNameWithTag}"

                    // Push the 'latest' tag
                    sh "podman push ${env.ECR_REGISTRY}:latest"
                    echo "'latest' tag pushed to ECR."
                }
            }
        }
        stage('Update Manifest') {
            steps {
                dir('eks-gitops/nodejs-app/k8s') {
                    sshagent([env.GIT_CREDENTIAL_ID]) {
                        script {
                            def activeEnv = sh(script: "cat active-env.txt || echo 'blue'", returnStdout: true).trim()
                            def newEnv = (activeEnv == 'blue') ? 'green' : 'blue'
                            def newEnvFile = "${newEnv}-deployment.yaml" // Maps newEnv to file name
                            sh """
                                git remote set-url origin ${env.REPO_SSH_URL}
                                # Update the inactive deployment's image and version
                                echo ${VERSION}
                                sed -i "s|image: ${ECR_REGISTRY}:.*|image: ${ECR_REGISTRY}:${VERSION}|" ${newEnvFile}
                                sed -i '/name: DEPLOYMENT_VERSION/{n;s|value: "v[^"]*"|value: "v'"${VERSION}"'"|}' ${newEnvFile}
                                
                                # Switch service to new environment
                                sed -i "s|env: .*|env: ${newEnv}|" service.yaml
                                
                                # Update active environment file
                                echo ${newEnv} > active-env.txt
                                git config user.email 'jenkins@nimaldas.com'
                                git config user.name 'NimalDas'
                                git add ${newEnvFile} service.yaml active-env.txt
                                git commit -m 'Switch to ${newEnv} deployment with version ${VERSION}'
                                git push origin main
                            """
                        }
                    }
                }
            }
        }
        // stage('Switch traffic') {
        //     when {
        //         expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
        //     }
        //     steps {
        //         script {
        //             input 'Switch traffic to new version? (Validate new deployment first)'
        //             dir('eks-gitops/nodejs-app/k8s') {
        //                 sshagent([env.GIT_CREDENTIAL_ID]) {
        //                     def activeEnv = sh(script: "cat active-env.txt || echo 'blue'", returnStdout: true).trim()
        //                     def newEnv = (activeEnv == 'blue') ? 'green' : 'blue'
        //                     sh """
        //                         git remote set-url origin ${env.REPO_SSH_URL}
        //                         sed -i "s|env: .*|env: ${newEnv}|" service.yaml
        //                         echo ${newEnv} > active-env.txt
        //                         git config user.email 'jenkins@nimaldas.com'
        //                         git config user.name 'NimalDas'
        //                         git add service.yaml active-env.txt
        //                         git commit -m 'Switch traffic to ${newEnv} with version ${VERSION}'
        //                         git push origin main
        //                     """
        //                 }
        //             }
        //         }
        //     }
        // }        
    }
    post {
        always {
            echo "Pipeline finished."
        }
    }
    
}
