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

> **Note** — this path pins Strimzi to chart `0.49.1` (`cd/templates/strimzi.yaml`)
> and its manifests under `kafka/` use the `kafka.strimzi.io/v1beta2` API. Current
> Strimzi (1.x) serves `v1` only, so bumping the pin means migrating those
> manifests at the same time. `quickstart.sh`, which tracks `latest`, is
> unaffected.

| Script | Role |
|---|---|
| `quickstart.sh` | The demo. Strimzi + a Kafka cluster, straight from upstream. |
| `run-all.sh` | The GitOps path: `prereq.sh` + `argocd.sh` + `e2e.sh`. |
| `prereq.sh` | Creates a kind cluster, installs OLM and the ArgoCD operator. |
| `argocd.sh` | Registers this repo as an ArgoCD app and syncs it. |
| `e2e.sh` | End-to-end check: the Kafka cluster answers. |
| `ignite.sh` | Installs the pinned tool versions via `ciux`. |
| `cd/` | ArgoCD `Application` manifests (Helm chart). |
| `kafka/` | The `Kafka`, `KafkaTopic` and `KafkaUser` resources ArgoCD deploys. |

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
