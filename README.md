# Usage

```jsonnet
local zk = (import './zookeeper.libsonnet');

{
    config+:: {
      namespace: 'hello-zookeeper'

    }
    zookeeper: zk {
      _config+:: $._config,
    },

}
```

A verbose variant:

```jsonnet
local k = import 'k.libsonnet';
local zk = import 'zookeeper-libsonnet/zookeeper.libsonnet';

{
    local this = self,

    _config+:: {
      namespace: 'zookeeper',

      zookeeper+: {
        pvc_class:: 'gp2',
      },
    
    },

    _images+:: {
      zookeeper: '1234567890.dkr.ecr.eu-west-1.amazonaws.com/zookeeper:3.7.0',
    },

    namespace: k.core.v1.namespace.new(this._config.namespace),

    zookeeper: zk {
      _config+:: this._config,
      _images+:: this._images,

      zookeeper+: {
        data_pvc+:: {
          storageClassName:: error('hiding this field intentionally to fall onto the default storageclass')
        },
        log_pvc+:: {
          storageClassName:: error('hiding this field intentionally to fall onto the default storageclass')
        },
      },
    },

  },
```
