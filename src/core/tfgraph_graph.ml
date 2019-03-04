(*
 * OWL - OCaml Scientific and Engineering Computing
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 * Copyright (c) 2019-2019 Jianxin Zhao <jianxin.zhao@cl.cam.ac.uk>
 *)


open Tfgraph_node
open Tfgraph_types


type tfgraph = {
  mutable nodes   : tfnode array;
  mutable version : string;
  mutable nametbl : (string, string) Hashtbl.t
}


type graphdef = {
  mutable tfmeta  : tfmeta;
  mutable tfgraph : tfgraph;
  mutable tfsaver : tfsaver;
  mutable tfcolls : tfcolls
}


(* Graph version is NOT tensorflow version;
 * defined by TF_GRAPH_DEF_VERSION in core/public/version.h
 *)
let create () =
  {
    nodes    = [||];
    version  = "27";
    nametbl  = (Hashtbl.create 20)
  }


let add_tfnodes tfgraph tfnodes name_update =
  tfgraph.nodes <- Array.append tfgraph.nodes tfnodes;
  let n_old, n_new = name_update in
  Hashtbl.add tfgraph.nametbl n_old n_new


(* a bad implementation; maybe change to Hashtbl later *)
let get_tfnode tfgraph name =
  let nodes = Array.to_list tfgraph.nodes in
  let ns = List.filter (fun n -> (get_name n) = name) nodes in
  match ns with
  | h :: _ -> h
  | []     -> failwith (Printf.sprintf "cannot get node %s from graph" name)


let to_pbtxt graphdef =
  let node_str = Owl_utils_array.to_string ~sep:"\n" (fun n ->
    to_pbtxt n
  ) graphdef.nodes
  in
  let version_str = Printf.sprintf "versions {\nproducer: %s\n}\n" graphdef.version in
  Printf.sprintf "graph_def {\n%s%s}\n" node_str version_str


(* To be used for connecting nodes in graph, with type/shape checking *)
let connect _node1 _node2 = ()
