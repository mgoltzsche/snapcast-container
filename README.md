# snapserver and snapclient containerized

[Snapcast](https://github.com/badaix/snapcast) server and client container images and Kubernetes manifest

## Development

### Prerequisites

* make
* docker 1.20+

### Build the application
To build the application container image using [skaffold](https://skaffold.dev, run:
```sh
make image
```

### Deploy the application
To deploy the application using [skaffold](https://skaffold.dev), run:
```sh
make deploy
```
To deploy the application in debug mode (debug ports forwarded), stream its logs and redeploy on source code changes automatically, run:
```sh
make debug
```

To undeploy the application, run:
```sh
make undeploy
```

### Apply blueprint updates
To apply blueprint updates to the application codebase, update the [kpt](https://kpt.dev/) package:
1. Before updating the package, make sure you don't have uncommitted changes in order to be able to distinguish package update changes from others.
2. Call `make update` or rather `kpg pkg update && kpt fn render` (the kpt render pipeline applies the configuration within [`setters.yamll`](./setters.yaml) to the manifests and `skaffold.yaml`).
3. Before committing the changes, review them carefully and make manual changes if necessary.

Details: https://kpt.dev/reference/cli/pkg/update/

### Makefile documentation

To get an overview of the available `Makefile` targets, run:
```sh
make help
```
