# RANCHER SETUP
Below is shown how setup rancher into a kubernetes cluster.

## Install metallb & nginx
First of all we need to install using:

```bash
kubectl apply -f <manifest_name>
```

in the following order:
- rancher/metallb/metallb-v0.13.10.yaml
- rancher/nginx/ingress-nginx-v1.10.1.yaml
- rancher/metallb/metallb-config.yaml

## Patch the nginx ingress (not necessary only if you want assign a static ip)
```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "X.X.X.X"}}'
```

To verify the previous command:
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Debug ingress
```bash
dalecosta@dalecostas-MBP helm % kubectl get pods -n ingress-nginx                                     

NAME                                           READY   STATUS      RESTARTS        AGE
ingress-nginx-252-6c76bb5b79-bblrn             1/1     Running     4               6d
ingress-nginx-admission-create-252-m56ds       0/1     Completed   0               5d23h
ingress-nginx-admission-create-c5mh6           0/1     Completed   0               20d
ingress-nginx-admission-patch-252-zqg7k        0/1     Completed   2               5d23h
ingress-nginx-admission-patch-8h9df            0/1     Completed   0               20d
ingress-nginx-controller-252-fc5d8ff7d-v44sh   1/1     Running     10 (106m ago)   5d21h
ingress-nginx-controller-6f59ffcc4-4fx4x       1/1     Running     13 (108m ago)   20d
dalecosta@dalecostas-MBP helm % kubectl logs ingress-nginx-controller-6f59ffcc4-4fx4x -n ingress-nginx

# enter in the ingress
kubectl exec -it ingress-nginx-controller-6f59ffcc4-4fx4x -n ingress-nginx -- /bin/sh

# get logs from ingress
kubectl logs ingress-nginx-controller-6f59ffcc4-4fx4x -n ingress-nginx
```

## Install cert-manager
Copy rancher/cert-manager/cert-manager-crd.yaml and:
```bash
kubectl apply -f cert-manager-crd.yaml
```
Now with helm we can contineu to install cert-manager on k8s cluster:
```bash
helm repo add jetstack https://charts.jetstack.io
```
```bash
helm repo update 
```
```bash
helm fetch jetstack/cert-manager --version v1.11.0
```
```bash
kubectl create namespace cert-manager
```
```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.11.0
```
To verify the corrected execution of the pods:
```bash
kubectl get pods -n cert-manager
kubectl get ingressclass
```

## Setup cluster-issuer and let's encrypt
To use https certificats we need to setup cluster-issuer using
a cloud provider like digital ocean, go daddy and so on.

Before to continue, we need to add the token to access to our dns/certificate provider.
In this example we use digital ocean but the same logic is valid for others providers.
To access to the provider, we need to add the token as secret:
```bash
kubectl create secret generic digitalocean-dns \
  --from-literal=access-token=<your-token> \
  -n cert-manager
```

Now, apply the letsencrypt cluster issuer (actually is linked to digital ocean because I use it. However you can update with your dns provider like cloudflare, go daddy and so on):
```bash
kubectl apply -f rancher/letsencrypt/letsencrypt-cluster-issuer.yaml
```

Then, we need to add the certificate linked to a specific namespace.
So basically, all services under the namespace can use the certificate uploaded:
```bash
kubectl apply -f rancher/letsencrypt/namespace-certificate.yaml
```

To verify
```bash
kubectl describe clusterissuer letsencrypt-digitalocean
kubectl get certificates.cert-manager.io -n <namespace>
kubectl get certificaterequest -n <namespace>
```


# Install rancher
Based on k8s version, you can install using helm from stable or latest:
```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
or
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
```
```bash
helm repo update
```
```bash
helm fetch rancher-stable/rancher --version=v2.10.3
or
helm fetch rancher-latest/rancher --version=v2.11.0
```
```bash
kubectl create namespace cattle-system
```
```bash
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=X.X.X.X.sslip.io \ # Or your.domain.com
  --set bootstrapPassword=admin

or

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=X.X.X.X.sslip.io \ # Or your.domain.com
  --set bootstrapPassword=admin
```

To assign a specific ip with metallb use:
```bash
kubectl patch svc rancher -n cattle-system \
  -p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "X.X.X.X"}}'
```

To verify the previous commnad:
```bash
kubectl get svc rancher -n cattle-system
```
