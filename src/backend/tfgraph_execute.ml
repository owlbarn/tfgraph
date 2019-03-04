(*
 * OWL - OCaml Scientific and Engineering Computing
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 * Copyright (c) 2019-2019 Jianxin Zhao <jianxin.zhao@cl.cam.ac.uk>
 *)


let execute_cgraph ?(_machine : string) ?(_device : graph_device) _graphdef _inputs = ()
  (*
   * 0. modify all the nodes' device property (to CPU, GPU, or TPU) according to "device" using "set_device"; to be explored
   * 1. serialise graphdef   (NOT tfgraph.proto; maybe just use string/bytes§)
   * 2. serialise all inputs (data.proto)
   * 3. send graph and input to backend service as bytes (how)
   * 4. get data result, deserialise (data.proto)
   *)
