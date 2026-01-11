pipeline {
    agent any

    environment {
        // Global variables
        DOCKER_REGISTRY = 'docker.io/hemantr1' // e.g., 'docker.io/username'
        IMAGE_NAME_BACKEND = 'ai-attendance-backend'
        IMAGE_NAME_FRONTEND = 'ai-attendance-frontend'
        KUBE_NAMESPACE = 'ai-attendance'
        SCANNER_HOME = tool 'SonarScanner' // Make sure SonarScanner is configured in Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Static Analysis & Security') {
            parallel {
                stage('OWASP Dependency Check') {
                    steps {
                        // Requires OWASP Dependency-Check Plugin
                        dependencyCheck additionalArguments: '--format HTML', odcInstallation: 'DP-Check' 
                    }
                }
                stage('SonarQube Analysis') {
                    steps {
                        script {
                            def scannerHome = tool 'SonarScanner' // Must match Global Tool Config Name
                            withSonarQubeEnv('SonarQube') {
                                sh "${scannerHome}/bin/sonar-scanner \
                                    -Dsonar.projectKey=ai-attendance \
                                    -Dsonar.sources=."
                            }
                        }
                    }
                }
                stage('Trivy File Scan') {
                    steps {
                         // Assumes Trivy is installed on the agent
                        sh 'trivy fs --exit-code 0 --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL .'
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                script {
                    // Build Backend
                    // Use empty string registry URL to default to Docker Hub (index.docker.io)
                    docker.withRegistry('', 'docker-credentials-id') {
                        def backendImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME_BACKEND}:${BUILD_NUMBER}", "./backend")
                        backendImage.push()
                        backendImage.push("latest")
                    }

                    // Build Frontend
                    docker.withRegistry('', 'docker-credentials-id') {
                        def frontendImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME_FRONTEND}:${BUILD_NUMBER}", "./frontend")
                        frontendImage.push()
                        frontendImage.push("latest")
                    }
                }
            }
        }

        stage('Image Security Scan (Trivy)') {
            steps {
                // Scan the built images
                sh "trivy image ${DOCKER_REGISTRY}/${IMAGE_NAME_BACKEND}:${BUILD_NUMBER}"
                sh "trivy image ${DOCKER_REGISTRY}/${IMAGE_NAME_FRONTEND}:${BUILD_NUMBER}"
            }
        }

        stage('Deploy to Dev') {
            steps {
                script {
                    // Deploy using Helm
                    // Assumes kubeconfig is set up or using a credentials plugin
                        // Deploy using SSH to bypass API Timeouts on t3.micro
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-jenkins', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        def remoteIp = "172.31.3.163" // Private IP
                        def sshCmd = "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${remoteIp}"
                        
                        // 1. Copy Helm Chart to Server
                        sh "scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r ./helm ubuntu@${remoteIp}:/home/ubuntu/"
                        
                        // 3. The "Fire and Forget" Strategy (K3s Auto-Deploy)
                        // K3s automatically watches /var/lib/rancher/k3s/server/manifests/
                        // If we drop a file there, K3s applies it internally (Bypassing HTTP/API/Kubectl timeouts).
                        sh """
                            # 1. Generate the Manifest File Locally on Jenkins
                            /usr/local/bin/helm template ai-attendance-dev ./helm/ai-attendance \
                            -f ./helm/values-dev.yaml \
                            --set backend.image.tag=${BUILD_NUMBER} \
                            --set frontend.image.tag=${BUILD_NUMBER} \
                            --namespace ai-attendance-dev --create-namespace > ai-attendance.yaml
                            
                            # 2. SCP the file to the server (tmp location first)
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ai-attendance.yaml ubuntu@${remoteIp}:/tmp/ai-attendance.yaml
                            
                            # 3. Move it to the Auto-Deploy folder (Sudo required)
                            # This returns instantly. K3s will pick it up asynchronously.
                            ${sshCmd} 'sudo mv /tmp/ai-attendance.yaml /var/lib/rancher/k3s/server/manifests/ai-attendance-dev.yaml'
                        """
                    }
                }
            }
        }

        stage('Deploy to Test') {
            input {
                message "Deploy to Test?"
                ok "Deploy"
            }
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-jenkins', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        def remoteIp = "172.31.3.163" 
                        def sshCmd = "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${remoteIp}"
                        
                        sh """
                            /usr/local/bin/helm template ai-attendance-test ./helm/ai-attendance \
                            -f ./helm/values-test.yaml \
                            --set backend.image.tag=${BUILD_NUMBER} \
                            --set frontend.image.tag=${BUILD_NUMBER} \
                            --namespace ai-attendance-test --create-namespace > ai-attendance-test.yaml
                            
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ai-attendance-test.yaml ubuntu@${remoteIp}:/tmp/ai-attendance-test.yaml
                            ${sshCmd} 'sudo mv /tmp/ai-attendance-test.yaml /var/lib/rancher/k3s/server/manifests/ai-attendance-test.yaml'
                        """
                    }
                }
            }
        }

        stage('Deploy to Prod') {
             input {
                message "Deploy to Production?"
                ok "Deploy"
            }
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-jenkins', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        def remoteIp = "172.31.3.163" 
                        def sshCmd = "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${remoteIp}"
                        
                        sh """
                            /usr/local/bin/helm template ai-attendance-prod ./helm/ai-attendance \
                            -f ./helm/values-prod.yaml \
                            --set backend.image.tag=${BUILD_NUMBER} \
                            --set frontend.image.tag=${BUILD_NUMBER} \
                            --namespace ai-attendance-prod --create-namespace > ai-attendance-prod.yaml
                            
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ai-attendance-prod.yaml ubuntu@${remoteIp}:/tmp/ai-attendance-prod.yaml
                            ${sshCmd} 'sudo mv /tmp/ai-attendance-prod.yaml /var/lib/rancher/k3s/server/manifests/ai-attendance-prod.yaml'
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            mail to: 'hregmi2060@gmail.com',
                 subject: "SUCCESS: AI Attendance Build #${env.BUILD_NUMBER}",
                 body: "Build #${env.BUILD_NUMBER} deployed successfully to Dev. Waiting for Test/Prod approval.\n\nCheck console: ${env.BUILD_URL}"
        }
        failure {
            mail to: 'hregmi2060@gmail.com',
                 subject: "FAILURE: AI Attendance Build #${env.BUILD_NUMBER}",
                 body: "Build #${env.BUILD_NUMBER} failed.\n\nCheck console: ${env.BUILD_URL}"
        }
    }
}
