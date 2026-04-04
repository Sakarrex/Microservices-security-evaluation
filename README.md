# Readme
This application is part of a Final Degree Project: **"Desarrollo de sistemas de microservicios, y evaluación de modelos arquitecturales y mecanismos de seguridad en relación al rendimiento."**

The main objective of the this application is the deployment of a Kubernetes cluster with an Istio service mesh, and evaluation of responce times and resource consumption, of security mechanisms implemented either in a API Gateway or Mesh Sidecars.

## Requirements 
* Ubuntu
* Docker
* Kubernetes flavor (Kind was used for this project)
* kubectl
* Istio
* Node.Js
* autocannon
* mkcert

## Structure

The project structure is divided in the following folders:
* `Certs/` Self signed certs necessesary for Https.
* `Docker-Images/` Microservices images to build and push to local registry.
* `Jwt-Components/` Token and jwks used for jwt authorization (added in case curl to github doesn't work).
* `Results/` Results from benchmarking.
* `Scripts/` Scripts for creating the k8s cluster, updating images to registry and running benchmark.
* `Yamls/` Manifest for cluster and security mechanisms deployments.

The application works by deploying a Gateway API (http only by default) that connects to a front microservice. This front microservice is then charged with calling a cpu-bench microservice, which multiplies an NxN matrix and returns the result, and a mem-bench microservice, that creates and deletes allocated memory through a c++ script, and returns the time it took.

## Running

First run the `Scripts/create.sh` script. It will: 
* Create the kind cluster.
* Create the self signed certs.
* Create and load the images to the local registry.
* Deploy the base aplication without security mechanisms.
* Apply the istio service mesh and gateway.
* Create a tunnel to the cluster and add it to the local dns under the domain **"mydomain.com"**
* Apply prometheus and kiali for monotoring.

If everything worked you should be able to access the cluster through the url `http://mydomain.com`, and call the bench services: `http://mydomain.com/mem` (mem-bench), `http://mydomain.com/cpu` (cpu-bench), and `http://mydomain.com/run` (both).

Once the create script has finish run `Scripts/runAllTests.sh` to start the benchmarking test. The `Scripts/runBenchmark.sh` is in charge of running one type of benchmark (Selecting one security protocol and one component to test it). It creates a http load with autocannon from which prometheus metrics will be scraped, the parameters it takes are: 
* Protocol (Waf,Jwt,Mtls,Control)
* Component (Gateway,Sidecar,All)
* Number of runs (5 by default)

All results will are written in the `Results/` folder.