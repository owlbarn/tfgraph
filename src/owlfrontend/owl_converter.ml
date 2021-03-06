(*
 * OWL - OCaml Scientific and Engineering Computing
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 * Copyright (c) 2019-2019 Jianxin Zhao <jianxin.zhao@cl.cam.ac.uk>
 *)


open Owl_graph

module TFcolls = Tfgraph_collection
module TFmeta  = Tfgraph_meta
module TFsaver = Tfgraph_saver


(**
  This functor takes a Owl computation graph as its input, then it generates
  the owl-tensorflow converter module without flattening the module hierarchy.
 *)

module Make
  (G : Owl_computation_graph_sig.Sig)
  = struct

  module TFgraph = Owl_converter_graph.Make (G)

  open TFgraph

  let make_tf_cgraph () =
    {
      tfmeta  = TFmeta.create  ();
      tfgraph = TFgraph.create ();
      tfsaver = TFsaver.create ();
      tfcolls = TFcolls.create ();
    }


  let parse_cgraph (graph : G.graph) =
    let outputs = G.get_outputs graph in

    (* 0th iterations: name each node *)
    iter_ancestors (fun node ->
      let name = Owl_graph.name node in
      let name = if (name <> "") then name else (
        let id = Owl_graph.id node in
        Printf.sprintf "owlnode%d" id
      ) in
      Owl_graph.set_name node name;
    ) outputs;

    (* 1st iteration : on owl_cgraph *)
    let tfgraph = TFgraph.create () in
    iter_ancestors (fun node ->
      TFgraph.expand_tfgraph tfgraph node
    ) outputs;

    (* 2nd iteration : change tf_nodes's input nodes' names
     * according to tfgraph.nametbl *)
    Array.iter (fun tfnode ->
      let inputs = Tfgraph_node.get_inputs tfnode in
      Array.iteri (fun i x ->
        try (
          let replace = Hashtbl.find tfgraph.nametbl x in
          inputs.(i) <- replace
        ) with Not_found -> ()
      ) inputs;
      Tfgraph_node.set_inputs tfnode inputs
    ) tfgraph.nodes;

    (* 3nd iteration : add meta/saver/collection operations based on tf_cgraph *)
    let tfmeta  = TFmeta.create () in

    let tfsaver = TFsaver.create () in
    TFsaver.add_savernodes tfsaver tfgraph;

    let tfcolls = TFcolls.create () in
    TFcolls.add_byteslist tfcolls "variables";
    TFcolls.add_byteslist tfcolls "trainable_variables";
    TFcolls.add_nodelist  tfcolls "result";

    let variable_counter = ref 0 in
    Array.iter (fun tfnode ->
      let opname = Tfgraph_node.get_op_name tfnode in
      if not (TFmeta.mem_opdef tfmeta opname) then (
        let tfop = Tfgraph_node.get_opdef tfnode in
        TFmeta.add_opdef tfmeta tfop
      );
      if (TFmeta.is_var tfnode) then (
        variable_counter := !variable_counter + 1;
        TFsaver.add_link tfsaver tfgraph tfnode;

        (* serialise variables *)
        let bytes = Tfgraph_node.get_linked_nodes tfnode |> Tfgraph_utils.serialise_variable in
        (* TODO: trainable_variables and variables are not always identical *)
        TFcolls.update_bytelist tfcolls "variables" bytes;
        TFcolls.update_bytelist tfcolls "trainable_variables" bytes
        
      )
    ) tfgraph.nodes;

    (* TODO: a tmp solution if no variable included in the graph *)
    if (!variable_counter = 0) then (
      let op = G.Optimiser.Operator.Symbol.Shape.Type.Ones [||] in
      let tfnodes, update = TFgraph.make_variable_nodes op "dummpy_var" [||] in
      TFgraph.add_tfnodes tfgraph tfnodes update;
      TFsaver.add_link tfsaver tfgraph tfnodes.(0);
    );

    let output_names = Array.map (fun n ->
      (Owl_graph.name n) ^ ":0"
    ) outputs
    in
    TFcolls.update_nodelist tfcolls "result" output_names;

    tfmeta, tfgraph, tfsaver, tfcolls


  let convert graph =
    let tf_cgraph = make_tf_cgraph () in
    let tfmeta, tfgraph, tfsaver, tfcolls = parse_cgraph graph in
    tf_cgraph.tfmeta  <- tfmeta;
    tf_cgraph.tfgraph <- tfgraph;
    tf_cgraph.tfsaver <- tfsaver;
    tf_cgraph.tfcolls <- tfcolls;
    tf_cgraph


  let to_pbtxt g =
    (TFmeta.to_pbtxt  g.tfmeta)  ^
    (TFgraph.to_pbtxt g.tfgraph) ^
    (TFsaver.to_pbtxt g.tfsaver) ^
    (TFcolls.to_pbtxt g.tfcolls)

end
