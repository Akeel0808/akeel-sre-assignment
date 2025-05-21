#!/bin/bash
set -e

echo "Deploying metrics-app with KIND and ArgoCD"
echo "--------------------------------------------"

# Install Required Tools
sudo apt install docker.io -y
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

echo "All required tools are installed."

echo "Creating KIND cluster..."
kind create cluster --config kind-config.yaml --name metrics-app-cluster || { echo "Failed to create KIND cluster. Aborting."; exit 1; }
echo "KIND cluster created successfully."

echo "Setting kubectl context..."
kubectl cluster-info --context kind-metrics-app-cluster

echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "Waiting for ArgoCD to be ready..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s

echo "Configuring ArgoCD ingress..."
kubectl apply -f argocd-ingress.yaml

echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "Applying ArgoCD application (make sure you've updated the Git repo URL)..."
kubectl apply -f argocd-application.yaml

echo "Waiting for the metrics-app to be deployed..."
sleep 30

echo "Checking application deployment status..."
kubectl get pods

echo "Deployment completed. You can now test the counter endpoint:"
echo "curl localhost:8080/counter"
echo ""
