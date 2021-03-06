(*
 * OWL - OCaml Scientific and Engineering Computing
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 * Copyright (c) 2019-2019 Jianxin Zhao <jianxin.zhao@cl.cam.ac.uk>
 *)


open Tfgraph_types
open Tfgraph_attr
open Tfgraph_node


let _ckpt_file_name = "owl_model"
let _save_name = "save/SaveV2"
let _restore_name = "save/RestoreV2"
let _save_tensor_names = "save/SaveV2/tensor_names"
let _save_shape_slices = "save/SaveV2/shape_and_slices"
let _restore_tensor_names = "save/RestoreV2/tensor_names"
let _restore_shape_slices = "save/RestoreV2/shape_and_slices"


module TFgraph = Tfgraph_graph


let create () =
  {
    filename_tensor_name = "save/Const";
    save_tensor_name = "save/control_dependency";
    restore_op_name = "save/restore_all";
    max_to_keep = 5;
    sharded = false;
    keep_checkpoint_every_n_hours = 10000.0
  }


let add_savernodes tfsaver tfgraph =

  let filename_tensor_name = make_tftensor
    ~string_val:[|_ckpt_file_name|] "DT_STRING" [||] in
  let save_const = TFConst (TFConst.create tfsaver.filename_tensor_name
    [||] (ATTR_Tensor filename_tensor_name))
  in

  let save_tensor_name = make_tftensor
    ~string_val:[||] "DT_STRING" [|0|] in
  let save_tensor_name = TFConst (TFConst.create _save_tensor_names
    [|0|] (ATTR_Tensor save_tensor_name))
  in

  let save_shape = make_tftensor
    ~string_val:[||] "DT_STRING" [|0|] in
  let save_shape = TFConst (TFConst.create _save_shape_slices
    [|0|] (ATTR_Tensor save_shape))
  in

  let save = TFSave (TFSave.create _save_name
    [|(get_name save_const);
      (get_name save_tensor_name);
      (get_name save_shape)|]
    [||])
  in
  let control_dep = TFIdentity (TFIdentity.create
    ~cls:[|tfsaver.filename_tensor_name|]
    tfsaver.save_tensor_name
    [|(get_name save_const); ("^" ^ (get_name save))|]
    [||] "DT_STRING"
  )
  in

  let restore_tensor_name = make_tftensor
    ~string_val:[||] "DT_STRING" [|0|] in
  let restore_tensor_name = TFConst (TFConst.create _restore_tensor_names
    [|0|] (ATTR_Tensor restore_tensor_name))
  in

  let restore_shape = make_tftensor
    ~string_val:[||] "DT_STRING" [|0|] in
  let restore_shape = TFConst (TFConst.create _restore_shape_slices
    [|0|] (ATTR_Tensor restore_shape))
  in

  let restore = TFRestore (TFRestore.create _restore_name
    [|(get_name save_const);
      (get_name restore_tensor_name);
      (get_name restore_shape)|]
    [||])
  in

  let restore_all = TFNoop (TFNoop.create tfsaver.restore_op_name [||]) in

  let nodes = [|
    save_const; save_tensor_name; save_shape; save; control_dep;
    restore_tensor_name; restore_shape; restore; restore_all
  |] in

  Array.iter (fun n ->
    TFgraph.add_tfnodes tfgraph [|n|] ("", "")
  ) nodes


let _add_const_string_value tfgraph node_name added =
  let node = TFgraph.get_tfnode tfgraph node_name in

  let out_shp = get_output_shape node in
  set_output_shape node [|out_shp.(0) + 1|];

  let const_val = get_value node in
  let string_val =
    match const_val with
    | ATTR_Tensor t -> t.string_val
    | _             -> failwith "incorrect value type"
  in
  let string_val =
    match string_val with
    | Some a -> Array.append a added
    | None   -> added
  in
  let new_tensor = make_tftensor ~string_val "DT_STRING" [|(Array.length string_val)|] in
  set_value node (ATTR_Tensor new_tensor)


let _get_const_string_value tfgraph node_name =
  let node = TFgraph.get_tfnode tfgraph node_name in
  let const_val = get_value node in
  let string_val =
    match const_val with
    | ATTR_Tensor t -> t.string_val
    | _             -> failwith "incorrect value type"
  in
  match string_val with
  | Some a -> a
  | None   -> [||]


let _add_input tfgraph node_name added =
  let node = TFgraph.get_tfnode tfgraph node_name in
  let inputs = get_inputs node in
  set_inputs node (Array.append inputs added)


let _add_dtypes tfgraph node_name added =
  let node = TFgraph.get_tfnode tfgraph node_name in
  let dtypes = get_dtypes node in
  set_dtypes node (Array.append dtypes added)


let add_link tfsaver tfgraph tfnode =
  let nname = get_name tfnode in
  let out_shp = get_output_shape tfnode in

  let id = _get_const_string_value tfgraph _save_tensor_names
    |> Array.length in
  (* let name = Printf.sprintf "%s/Assign_%d" nname id in *)
  let name = Printf.sprintf "save/Assign_%d" id in
  let vname = Printf.sprintf "%s:%d" _restore_name id in
  let assign_node = TFAssign (TFAssign.create ~refv:nname
    ~value:vname name out_shp "DT_FLOAT")
  in

  _add_input tfgraph _save_name [|nname|];
  _add_input tfgraph tfsaver.restore_op_name [|("^" ^ name)|];

  _add_dtypes tfgraph _save_name [|"DT_FLOAT"|];
  _add_dtypes tfgraph _restore_name [|"DT_FLOAT"|];

  _add_const_string_value tfgraph _save_tensor_names [|nname|];
  _add_const_string_value tfgraph _save_shape_slices [|""|];
  _add_const_string_value tfgraph _restore_tensor_names [|nname|];
  _add_const_string_value tfgraph _restore_shape_slices [|""|];

  TFgraph.add_tfnodes tfgraph [|assign_node|] ("", "")


let to_pbtxt saver =
  let saver_str =
    (Printf.sprintf "filename_tensor_name : \"%s:0\"\n" saver.filename_tensor_name) ^
    (Printf.sprintf "save_tensor_name : \"%s:0\"\n" saver.save_tensor_name) ^
    (Printf.sprintf "restore_op_name : \"%s\"\n" saver.restore_op_name) ^
    (Printf.sprintf "max_to_keep : %d\n" saver.max_to_keep) ^
    (Printf.sprintf "sharded: %b\n" saver.sharded) ^
    (Printf.sprintf "keep_checkpoint_every_n_hours: %f\n" saver.keep_checkpoint_every_n_hours) ^
    (Printf.sprintf "version: V2\n")
  in
  Printf.sprintf "saver_def {\n%s}\n" saver_str
