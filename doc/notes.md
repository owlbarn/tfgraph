# Plan

Here is what I'm going to do considering the workflow (stated below):
- do NOT bother with the backend service for now;
- instead, first check how to set device to CPU and GPU;
- second, think about what kind of information I can get from Tensorflow's side. For example, can I get XLA IR back?
- also think about the type/shape checking in constructing a tfgraph.


# Workflow

Here is the workflow I'm thinking about:

```ocaml
let tfgraph = T.convert g

(* here we can save the tfgraph as pbtxt; or we can also do this... *)
let inputs = [| Arr.ones [|100|] |]
let machine = "127.0.0.1"
let device = CPU
let result = execute_cgraph ~machine ~device tfgraph inputs
let _ = Arr.print result.(0)
```

We assume a (python) backend service is running on a machine, e.g. `localhost`.
Suppose it already has TensorFlow installed.
This service accepts the `tfgraph` and input data list, process it with TensorFlow, and return the output data.
The exchange data format between OCaml and this backend is protobuf-serialised bytes data.

The benefit of this workflow is that user can stay in Owl to use GPU/TPU, just like what Julia etc. did.
But that means the burden is on us now. We need to take care of graph and data serialisation, the backend service, etc.
Though in doing this, we may be able to get more information, such as XLA IR, from the TensorFlow backend.

I do suspect that, to make it a truly useful tool, we need to take care of this kind of tooling one day or the other.
However, my current doubt is that, if the system boundary is unnecessarily expanded too wide and too early.
... Quite possible.
