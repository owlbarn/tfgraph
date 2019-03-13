# Plan

Here is what I'm going to do considering the workflow (stated below):
- **do NOT bother with the backend service for now**;
- instead, first check how to set device to CPU and GPU;
- second, think about what kind of information I can get from Tensorflow's side. For example, can I get XLA IR back?
- also think about the type/shape checking in constructing a tfgraph.


# Workflow

Here is the workflow I'm thinking about:

```ocaml
let tfgraph = T.convert g

(* here we can save the tfgraph as pbtxt as before;
 * or we can also do this... *)
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

# Todo List

- incorporating the `unknown_rank` situation; empty shape should be printed as is
- Graph version is NOT tensorflow version; defined by `TF_GRAPH_DEF_VERSION` in `core/public/version.h`. Should get version from tensorflow itself, probably by running command `python -c 'import tensorflow as tf; print(tf.__version__)'` instead of setting fixed version string.
- `tftensor` should contain more types: double_val, int_val, ... though only one of these fields should be used.
- `tfop_attr`: more properties: `allowed_values/default_value : tfattrvalue`, `has_minimum : bool`, `minimum : int`, etc.
- Similarly, `tfop` should contain more: `allows_uninitialized_input`, `is_commutative`,`is_stateful`, etc.
- Is the input name update part really necessary?
- `get_tfnode` implementation in `owl_converter_graph` is not efficient. May need to change to Hashtbl later.
- Ignore the init nodes in `make_variable_nodes`. Looks fine so far.
- In `make_stridedslice_nodes`, note that the four zeros are tmp dummy numbers. May need to be updated. Beware of the slicing functions anyway.
- `make_l2norm_sqr_nodes`: Be aware of those operation that does not have same input and output shapes. Also, the l2norm here is NOT `tf.math.l2_normalize`. Also here, I actually need to know how make_sum_nodes works, which does not look like a good system design.
- `make_conv2dbackkernel_nodes`: construct a const node like this is not the only way to represent the shape; a ShapeN node could also be used here.
- In the main `make_tfnodes`: even if tfgraph is taken in as a parameter, that still doesn't ensure a node have global access -- in Sum's case, it needs access to its parents, which are not put into tfgraph yet.
- `Add` op: actually, it will be translated to `TFBiasAdd` in DNN example; need to investigate if any condition is included.
- `OfArray` op: Only support 1-dim array for now; may need to find a more proper tensorflow operation.
- `GetSlice` op: be careful when index contains less item than the full length.
- The name "expand_tfgraph" is not very good.
- Things not yet considered in `convert`:
  * the "device" attr needs to be printed out for save/restore nodes
  * data type fixed to DT_FLOAT
  * some seemingly unimportant attr of nodes like "default_value" are emitted. Add when required.
  * all those random length of Hashtbl.
