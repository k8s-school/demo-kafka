# demo-kafka

A small, self-contained demo of the **Kubernetes operator pattern**, using
[Strimzi](https://strimzi.io/) to run Apache Kafka.

The point is not Kafka. The point is watching an operator do its job: you declare
*what* you want with a custom resource, and a controller reconciles the cluster
until reality matches. Kafka is just a convincing example — it is genuinely hard
to operate by hand, and Strimzi makes it look easy.

## Prerequisites

- A running Kubernetes cluster (a [kind](https://kind.sigs.k8s.io/) cluster is plenty)
- `kubectl`, configured on that cluster
- [`ink`](https://github.com/k8s-school/ink) for the log output:
  `go install github.com/k8s-school/ink@latest`

## Quickstart

```bash
./quickstart.sh
```

Two minutes later you have a working Kafka cluster. The script:

1. creates the `kafka` namespace,
2. installs the Strimzi **operator** (its CRDs + its controller Deployment),
3. applies a `Kafka` **custom resource**,
4. waits for the operator to reconcile it,
5. lists the topics from inside the broker.

## What just happened

That is the whole operator pattern, in three commands.

**The operator taught the cluster a new vocabulary.** Kubernetes had no idea what
a Kafka cluster was; now it does:

```bash
kubectl get crd | grep strimzi
```

**You declared intent, not steps.** One short YAML says "I want a Kafka cluster".
You never ran a single `kafka-*.sh` setup command:

```bash
kubectl get kafka -n kafka
```

```
NAME         READY   WARNINGS   KAFKA VERSION   METADATA VERSION
my-cluster   True               4.3.1           4.3-IV0
```

**A controller made it real.** The operator created the broker, the entity
operator, the services, the storage:

```bash
kubectl get pods -n kafka
```

## Things to try

The reconciliation loop is best seen by breaking things.

**Kill a broker and watch it come back.** Nobody tells Kubernetes to rebuild it —
the operator notices the drift and fixes it:

```bash
kubectl delete pod my-cluster-dual-role-0 -n kafka
kubectl get pods -n kafka -w
```

**Ask for a topic declaratively.** No `kafka-topics.sh --create`, just a resource:

```bash
kubectl apply -n kafka -f - <<'EOF'
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: my-topic
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 1
EOF

kubectl get kafkatopics -n kafka
```

```
NAME       CLUSTER      PARTITIONS   REPLICATION FACTOR   READY
my-topic   my-cluster   3            1                    True
```

Then check that Kafka itself agrees:

```bash
kubectl exec my-cluster-dual-role-0 -c kafka -n kafka -- \
  bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list
```

**Read the operator's mind.** Its logs are the reconciliation loop, out loud:

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator -f
```

## Where to look to understand operators

Four things make an operator. Each one is visible in this demo — here is where.

### 1. The CRD: a new kind of object

The operator's install manifest carries CRDs. They are what lets the API server
accept `kind: Kafka` at all, validate it, and store it in etcd. Note the `status`
subresource: the user writes `spec`, the controller writes `status`, and they
never fight over the same field.

```bash
kubectl get crd kafkas.kafka.strimzi.io -o yaml | head -40
kubectl explain kafka.spec.kafka          # the schema, straight from the CRD
```

### 2. The custom resource: your intent

In this repo, [`kafka/kafka-cluster.yaml`](kafka/kafka-cluster.yaml) is the whole
point: ~50 lines describing a Kafka cluster. No StatefulSet, no Service, no PVC —
those are consequences, not instructions. [`kafka/kafka-topic.yaml`](kafka/kafka-topic.yaml)
and [`kafka/kafka-user.yaml`](kafka/kafka-user.yaml) do the same for topics and users.

### 3. The controller: a Deployment that watches and acts

The operator itself is an ordinary Deployment. Its logs *are* the reconciliation
loop:

```bash
kubectl get deployment strimzi-cluster-operator -n kafka
kubectl logs -n kafka deployment/strimzi-cluster-operator -f
```

And it reports back through `status.conditions` — this is how `kubectl wait
kafka/my-cluster --for=condition=Ready` works, and why `quickstart.sh` waits on
the resource rather than on pods:

```bash
kubectl get kafka my-cluster -n kafka -o jsonpath='{.status.conditions}' | jq
```

### 4. The RBAC: why operators are powerful (and risky)

A controller that creates StatefulSets, Services and Secrets cluster-wide needs
permissions to match. This is the part to read before installing any operator in
production:

```bash
kubectl get clusterrole | grep strimzi
kubectl get clusterrole strimzi-cluster-operator-global -o yaml
```

### The ownership chain

Everything the operator creates is linked back to your resource by
`ownerReferences`, which is why deleting the `Kafka` object cascades — and why
deleting a *pod* only gets it rebuilt:

```
Pod/my-cluster-dual-role-0
  └── owned by StrimziPodSet/my-cluster-dual-role
        └── owned by KafkaNodePool/dual-role
              └── (root: the resource you applied)
```

Follow it yourself:

```bash
kubectl get pod my-cluster-dual-role-0 -n kafka \
  -o jsonpath='{.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}'
```

`StrimziPodSet` is worth a pause: Strimzi replaced StatefulSets with its *own*
CRD, because it needed per-pod control StatefulSets do not offer. An operator can
define the primitives it wishes Kubernetes had.

## The GitOps variant

`quickstart.sh` installs things imperatively. The repository also carries a
declarative path, where **ArgoCD** syncs the operator and the Kafka cluster from
this very repository:

```bash
./run-all.sh
```

It is heavier — it builds its own kind cluster and installs OLM and ArgoCD — and
it needs [`ciux`](https://github.com/k8s-school/ciux) on top of the prerequisites
above. Use it to show how an operator is deployed in a real GitOps setup, not for
a first look at operators.

Here the operator is itself deployed declaratively: `cd/templates/strimzi.yaml`
is an ArgoCD `Application` pointing at the Strimzi Helm chart, and
`cd/templates/kafka.yaml` is a second one pointing at this repo's `kafka/`
directory. Two levels of the same idea — a resource describing a desired state,
and a controller making it true.

## Repository map

| Path | What it is | Read it to see |
|---|---|---|
| `quickstart.sh` | The demo. Strimzi + a Kafka cluster from upstream. | The whole pattern in ~5 commands |
| `kafka/kafka-cluster.yaml` | The `Kafka` + `KafkaNodePool` resources | **Declared intent**, the core of the demo |
| `kafka/kafka-topic.yaml` | A `KafkaTopic` | A topic as a Kubernetes object |
| `kafka/kafka-user.yaml` | A `KafkaUser` | Credentials as a Kubernetes object |
| `cd/templates/strimzi.yaml` | ArgoCD `Application` for the operator | How an operator is installed via GitOps |
| `cd/templates/kafka.yaml` | ArgoCD `Application` for the cluster | How the CRs are synced from git |
| `run-all.sh` | The GitOps path: `prereq.sh` + `argocd.sh` + `e2e.sh` | |
| `prereq.sh` | Creates a kind cluster, installs OLM and the ArgoCD operator | OLM, the *other* way to ship operators |
| `argocd.sh` | Registers this repo as an ArgoCD app and syncs it | |
| `e2e.sh` | End-to-end check: the Kafka cluster answers | Gating on `condition=Ready` |
| `ignite.sh` | Installs the pinned tool versions via `ciux` | |

## Cleanup

`quickstart.sh` is re-runnable: it drops any namespace labelled `kafka=true` on
the way in, and re-installs Strimzi with a server-side apply, so the CRDs and
ClusterRoles left behind by the previous run are updated instead of colliding.

To remove the namespace by hand:

```bash
kubectl delete namespace -l kafka=true
```

That leaves Strimzi's cluster-scoped objects in place. To get rid of those too:

```bash
kubectl delete -f 'https://strimzi.io/install/latest?namespace=kafka'
```
