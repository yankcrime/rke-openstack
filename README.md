# RKE on OpenStack

This repo scratches my own itch when it comes to deploying Kubernetes using [RKE](https://rancher.com/products/rke/) on OpenStack.

You'll need a fairly standard OpenStack deployment with LBaaS via Octavia.  The code in this repo assumes that it's a "public" OpenStack cloud with an EC2-esque network configuration in which instances are provisioned on a private network and are allocated floating IP addresses where necessary.

Block storage via Cinder isn't currently supported.

## Pre-requisites

Edit `terraform.tfvars` and specify the name of your SSH keypair and your OpenStack API password.  You can also increase the number of controller nodes and worker nodes if necessary.  Note that controller nodes have to be an odd number, as these run etcd and an odd number is required in order to establish cluster quorum.

Install the required Terraform providers as dependencies:

```shell
$ terraform init
```

You'll need to manually (for now) install the RKE provider by following the instructions here: https://github.com/rancher/terraform-provider-rke

## Deploying

```shell
$ terraform plan -out plan.out
 
[..]

Plan: 26 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

This plan was saved to: plan.out

To perform exactly these actions, run the following command to apply:
    terraform apply "plan.out"

$ terraform apply plan.out
module.rancher-network.openstack_networking_network_v2.rancher_network: Creating...
module.rke-masters.openstack_networking_floatingip_v2.instance_fip[0]: Creating...
module.rancher-network.openstack_networking_router_v2.rancher_router: Creating...
module.rke-workers.openstack_networking_floatingip_v2.instance_fip[0]: Creating...

[..]

Apply complete! Resources: 26 added, 0 changed, 0 destroyed.

```

Deploying a cluster should take somewhere between 5-10 minutes.  Once your cluster has successfully deployed, you can source the generated kubeconfig file by doing:

```shell
$ export KUBECONFIG=$(pwd)/kube_config_cluster.yml
```

And verify that Kubernetes is OK:

```shell
$ kubectl get nodes
NAME                                   STATUS   ROLES               AGE     VERSION
sausages-controlplane-etcd-instance1   Ready    controlplane,etcd   2m49s   v1.17.4
sausages-worker-instance1              Ready    worker              2m41s   v1.17.4
```

Now wait for the various system-related pods and jobs to run to completion and become ready:

```shell
$ kubectl get pods -A
NAMESPACE       NAME                                      READY   STATUS      RESTARTS   AGE
ingress-nginx   default-http-backend-67cf578fc4-9h7hv     1/1     Running     0          2m27s
ingress-nginx   nginx-ingress-controller-dsvxt            1/1     Running     0          2m27s
kube-system     canal-9wdrq                               2/2     Running     0          3m14s
kube-system     canal-qj8pm                               2/2     Running     0          3m14s
kube-system     coredns-7c5566588d-klpmr                  1/1     Running     0          3m2s
kube-system     coredns-autoscaler-65bfc8d47d-ffvqh       1/1     Running     0          3m1s
kube-system     metrics-server-6b55c64f86-9pckk           1/1     Running     0          2m54s
kube-system     rke-coredns-addon-deploy-job-9d2hg        0/1     Completed   0          3m8s
kube-system     rke-ingress-controller-deploy-job-nwtcw   0/1     Completed   0          2m46s
kube-system     rke-metrics-addon-deploy-job-zl4dn        0/1     Completed   0          2m58s
kube-system     rke-network-plugin-deploy-job-24qv9       0/1     Completed   0          3m19s
```

At this point your cluster is ready to use.

## Post-deployment

The deployment code in this example configures the in-tree OpenStack cloud controller.  This means that any services you create of type LoadBalancer to expose your application will automatically create an OpenStack Octavia loadbalancer and allocate a public IP address.  You can test this functionality by doing the following:

```shell
$ kubectl run echoserver --image=gcr.io/google-containers/echoserver:1.10 --port=8080
pod/echoserver created
$ cat <<EOF | kubectl apply -f -
---
kind: Service
apiVersion: v1
metadata:
  name: loadbalanced-service
spec:
  selector:
    run: echoserver
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
EOF
service/loadbalanced-service created
```

Now verify that the service we've created has an External IP allocated.  This might stay in `<pending>` for a brief while until the Octavia loadbalancer is available:

```shell
$ kubectl get service loadbalanced-service
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)        AGE
loadbalanced-service   LoadBalancer   10.43.154.100   193.16.42.81   80:32023/TCP   2m7s
```

And to test:

```shell
$ curl 193.16.42.81

Hostname: echoserver

[..]
```

### Stateful workloads

If you want to deploy stateful workloads with a volume resource definition (for example when defining a StatefulSet) then you need to add the local-path-provisioner:

```shell
$ kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
namespace/local-path-storage created
serviceaccount/local-path-provisioner-service-account created
clusterrole.rbac.authorization.k8s.io/local-path-provisioner-role created
clusterrolebinding.rbac.authorization.k8s.io/local-path-provisioner-bind created
deployment.apps/local-path-provisioner created
storageclass.storage.k8s.io/local-path created
configmap/local-path-config created

$ kubectl annotate storageclass --overwrite local-path storageclass.kubernetes.io/is-default-class=true
storageclass.storage.k8s.io/local-path annotated
```

## Troubleshooting

If your Pods sit in pending, it could be because the cloud controller manager hasn't removed the NoSchedule taint on your worker nodes.  If it's created the loadbalancer OK but no pods are being scheduled, go ahead and remove the taint:

```shell
$ kubectl taint node --selector='!node-role.kubernetes.io/master' node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule-
node/sausages-controlplane-etcd-instance1 untainted
node/sausages-worker-instance1 untainted
```

Your Pods should move to `ContainerCreating`.

