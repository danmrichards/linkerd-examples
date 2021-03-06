# Hello World

## linkerd-to-linkerd using Kubernetes DaemonSets and linkerd-viz

This is a sample application to demonstrate how to deploy a linkerd-to-linkerd
configuration on Kubernetes using DaemonSets. The application consists of two
go services: hello and world. The hello service calls the world service.

```
hello -> linkerd (outgoing) -> linkerd (incoming) -> world
```

## Building

The Docker image for the hello and world services is [buoyantio/helloword](
https://hub.docker.com/r/buoyantio/helloworld/). There are instructions for
building the image yourself in the [`docker/helloworld`](../docker/helloworld)
directory.

## Deploying

### Hello World

Start by deploying the hello and the world apps by running:

```bash
kubectl apply -f k8s/hello-world.yml
```

Note that this app configuration does not work on [Minikube](
https://github.com/kubernetes/minikube) or versions of
Kubernetes older than 1.4. If you are on one of those platforms, then you can
instead use the legacy app configuration by running:

```bash
kubectl apply -f k8s/hello-world-legacy.yml
```

Either of these commands will create new Kubernetes Services and
ReplicationControllers for both the hello app and the world app.

### linkerd

Next deploy linkerd. There are multiple different linkerd deployment
configurations listed below, showcasing different linkerd features. Pick which
one is best for your use case.

#### Daemonsets

For the most basic linkerd DaemonSets configuration, you can run:

```bash
kubectl apply -f k8s/linkerd.yml
```

That command will create linkerd's config file as a Kubernetes ConfigMap, and
use the config file to start linkerd as part of a Kubernetes DaemonSet. It will
also add a Kuberentes Service for granting external access to linkerd.

This configuration is covered in more detail in:

* [A Service Mesh for Kubernetes, Part II: Pods Are Great Until They're Not](https://blog.buoyant.io/2016/10/14/a-service-mesh-for-kubernetes-part-ii-pods-are-great-until-theyre-not/)

#### Daemonsets + CNI

If you are using CNI such as Calico or Weave, you need a slightly modified
config as described [here](https://linkerd.io/getting-started/k8s-daemonset/index.html#cni-setups).

To deploy this configuration, you can run:

```bash
kubectl apply -f k8s/linkerd-cni.yml
```

#### Daemonsets + TLS

For a linkerd configuration that adds TLS to all service-to-service calls, run:

```bash
kubectl apply -f k8s/certificates.yml
kubectl apply -f k8s/linkerd-tls.yml
```

Those commands will create the TLS certificates as a Kubernetes Secret, and use
the certificates and the linkerd config to start linkerd as part of a Kubernetes
DaemonSet and encrypt all traffic between linkerd instances using TLS.

This configuration is covered in more detail in:

* [A Service Mesh for Kubernetes, Part III: Encrypting all the things](https://blog.buoyant.io/2016/10/24/a-service-mesh-for-kubernetes-part-iii-encrypting-all-the-things/)

#### Daemonsets + namerd + edge routing

To run linkerd and [namerd](https://linkerd.io/in-depth/namerd/) together, with
linkerd running in DaemonSets and serving edge traffic, run:

```bash
kubectl apply -f k8s/namerd.yml
kubectl apply -f k8s/linkerd-namerd.yml
```

Note: namerd stores dtabs with the Kubernetes master via the [ThirdPartyResource
APIs](https://kubernetes.io/docs/user-guide/thirdpartyresources/), which
requires a cluster running Kubernetes 1.2+ with the ThirdPartyResource feature
enabled.

Those commands will create the dtab resource, create the namerd config file,
start namerd, create the "external" and "internal" namespaces in namerd, create
the linkerd config file, and start linkerd, which will use namerd for routing.
linkerd will also run an edge router for handling external web traffic.

This configuration is covered in more detail in:

* [A Service Mesh for Kubernetes, Part IV: Continuous deployment via traffic shifting](https://blog.buoyant.io/2016/11/04/a-service-mesh-for-kubernetes-part-iv-continuous-deployment-via-traffic-shifting/)

#### Daemonsets + ingress + NGINX

To deploy a version of linkerd that uses NGINX for edge routing, and routing
traffic to multiple different backends based on domain, run:

```bash
kubectl apply -f k8s/nginx.yml
kubectl apply -f k8s/linkerd-ingress.yml
kubectl apply -f k8s/api.yml
```

Those commands will deploy a version of NGINX that's configured to route traffic
to linkerd. linkerd is configured to route requests on the `www.hello.world`
domain to the hello service, and requests on the `api.hello.world` to the API
service.

This configuration is covered in more detail in:

* [A Service Mesh for Kubernetes, Part V: Dogfood environments, ingress and edge routing](https://blog.buoyant.io/2016/11/18/a-service-mesh-for-kubernetes-part-v-dogfood-environments-ingress-and-edge-routing/)

#### Daemonsets + Zipkin

For a linkerd configuration that exports tracing data to Zipkin, first start
Zipkin, and then start linkerd with a Zipkin tracer configured:

```bash
kubectl apply -f k8s/zipkin.yml
kubectl apply -f k8s/linkerd-zipkin.yml
```

Those commands will start a Zipkin process in your cluster, running with an
in-memory span store and scribe collector, receiving linkerd tracing data via
the `io.l5d.zipkin` tracer.

This configuration is covered in more detail in:

* [A Service Mesh for Kubernetes, Part VII: Distributed tracing made easy](https://blog.buoyant.io/2017/03/14/a-service-mesh-for-kubernetes-part-vii-distributed-tracing-made-easy/)

#### Daemonsets + Ingress Controller

To route to external requests using ingress resources, deploy linkerd as an
ingress controller and create an ingress resource:

```bash
kubectl apply -f k8s/linkerd-ingress-controller.yml
kubectl apply -f k8s/hello-world-ingress.yml
```

### linkerd-viz

And lastly, once you have linkerd deployed, you can deploy
[linkerd-viz](https://github.com/linkerd/linkerd-viz) as well, by running:

```bash
kubectl apply -f https://raw.githubusercontent.com/linkerd/linkerd-viz/master/k8s/linkerd-viz.yml
```

## Verifying

Use the commands below to test out the app configurations that you deployed in
the previous section. Note that if you're running on Minikube, the verification
commands are different, and are covered in the next section,
[Verifying Minikube](#verifying-minikube).

### linkerd admin page

View the linkerd admin dashboard:

```bash
L5D_INGRESS_LB=$(kubectl get svc l5d -o jsonpath="{.status.loadBalancer.ingress[0].*}")
open http://$L5D_INGRESS_LB:9990 # on OS X
```

Note: Kubernetes deploys loadbalancers asynchronously, which means that there
can be a lag time from when a service is created to when its external IP is
available. If the command above fails, make sure that the `EXTERNAL-IP` field in
the output of `kubectl get svc l5d` is not still in the `<pending>` state. If it
is, wait until the external IP is available, and then re-run the command.

### namerd admin page

If you deployed namerd, view the namerd admin dashboard:

```bash
NAMERD_INGRESS_LB=$(kubectl get svc namerd -o jsonpath="{.status.loadBalancer.ingress[0].*}")
open http://$NAMERD_INGRESS_LB:9990 # on OS X
```

### Zipkin

If you deployed Zipkin, load the Zipkin UI:

```bash
ZIPKIN_LB=$(kubectl get svc zipkin -o jsonpath="{.status.loadBalancer.ingress[0].*}")
open http://$ZIPKIN_LB # on OS X
```

### Test Requests

Send some test requests:

```bash
http_proxy=$L5D_INGRESS_LB:4140 curl -s http://hello
http_proxy=$L5D_INGRESS_LB:4140 curl -s http://world
```

If you deployed namerd, then linkerd is also setup to proxy edge requests:

```bash
curl http://$L5D_INGRESS_LB
```

If you deployed NGINX, then you can also use that to initiate requests:

```bash
NGINX_LB=$(kubectl get svc nginx -o jsonpath="{.status.loadBalancer.ingress[0].*}")
curl -H 'Host: www.hello.world' http://$NGINX_LB
curl -H 'Host: api.hello.world' http://$NGINX_LB
```

### linkerd-viz dashboard

View the linkerd-viz dashboard:

```bash
L5D_VIZ_LB=$(kubectl get svc linkerd-viz -o jsonpath="{.status.loadBalancer.ingress[0].*}")
open http://$L5D_VIZ_LB # on OS X
```

## Verifying Minikube

If you're not running on Minikube, see the previous [Verifying](#verifying)
section.

### linkerd admin page

To view the linkerd admin dashboard:

```bash
minikube service l5d --url | tail -n1 | xargs open # on OS X
```

### namerd admin page

If you deployed namerd, view the namerd admin dashboard:

```bash
minikube service namerd --url | tail -n1 | xargs open # on OS X
```

### Zipkin

If you deployed Zipkin, view the Zipkin UI:

```bash
minikube service zipkin
```

### linkerd-viz dashboard

If you deployed linkerd-viz, view the linkerd-viz dashboard:

```bash
minikube service linkerd-viz --url | head -n1 | xargs open # on OS X
```

### Test Requests

Send some test requests:

```bash
L5D_INGRESS_LB=$(minikube service l5d --url | head -n1)
http_proxy=$L5D_INGRESS_LB curl -s http://hello
http_proxy=$L5D_INGRESS_LB curl -s http://world
```

## gRPC

There's also a gRPC version of the hello world example available. Start by
deploying linkerd configured to route gRPC requests:

```bash
kubectl apply -f k8s/linkerd-grpc.yml
```

Then deploy the hello and world services configured to communicate using gRPC:

```bash
kubectl apply -f k8s/hello-world-grpc.yml
```

View the linkerd admin dashboard (may take a few minutes until external IP is
available):

```bash
L5D_INGRESS_LB=$(kubectl get svc l5d -o jsonpath="{.status.loadBalancer.ingress[0].*}")
open http://$L5D_INGRESS_LB:9990 # on OS X
```

Send a test request using the `helloworld-client` script, provided by the
buoyantio/helloworld docker image:

```bash
docker run --rm --entrypoint=helloworld-client buoyantio/helloworld:0.1.2 $L5D_INGRESS_LB:4140
```
