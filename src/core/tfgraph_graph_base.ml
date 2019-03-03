open Tfgraph_node


type tfgraph = {
  mutable nodes   : tfnode array;
  mutable version : string;
  mutable nametbl : (string, string) Hashtbl.t
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
