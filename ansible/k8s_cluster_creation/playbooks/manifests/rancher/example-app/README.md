## Testing locally the build
```bash
go mod init go-hello-world && go mod tidy 
```
And then
```bash
go build -o main . 
```


## Testing the docker image
```bash
docker build -t go-hello-world .
```
Subsequentally run the container
```bash
docker run -p 8080:8080 go-hello-world
```
And finally test the API
```bash
curl http://localhost:8080       
curl http://localhost:8080/health
```


## Publish docker image
```bash
docker build -t my-repo/hello-world:latest . && docker push my-repo/hello-world:latest
```


## Local tests 
Enter inside the helm folder and then:
```bash
helm template hello-world ./hello-world \
  -f ./hello-world/values-hw1.yaml \
  -f ./hello-world/values-sec-hw1.yaml \
  --debug > generated-output-hw1.yaml
```
```bash
helm template hello-world ./hello-world \
  -f ./hello-world/values-hw2.yaml \
  -f ./hello-world/values-sec-hw2.yaml \
  --debug > generated-output-hw2.yaml
```

## Deploy to K8S Cluster
Install to the k8s cluster using the generated output
```bash
kubectl create namespace hello-app
kubectl apply -f generated-output-hw1.yaml
kubectl apply -f generated-output-hw2.yaml
```
For monitoring
```bash
kubectl get pods -n hello-app
kubectl describe pod <pod_name> -n hello-app
kubectl get svc -n hello-app
```
