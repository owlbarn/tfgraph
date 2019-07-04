(*
 * OWL - OCaml Scientific and Engineering Computing
 * Copyright (c) 2016-2019 Liang Wang <liang.wang@cl.cam.ac.uk>
 * Copyright (c) 2019-2019 Jianxin Zhao <jianxin.zhao@cl.cam.ac.uk>
 *)


open Tfgraph_types
open Tfgraph_node
open Tfgraph_attr


(**
  This functor takes a Owl computation graph as its input, then it generates
  the tensorflow graph module without flattening the module hierarchy.
 *)

module Make
  (G : Owl_computation_graph_sig.Sig)
  = struct

  include Tfgraph_graph

  open G.Optimiser.Operator

  module Device = G.Optimiser.Operator.Symbol.Shape.Type.Device


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


  let get_tfnode tfgraph name =
    let nodes = Array.to_list tfgraph.nodes in
    let ns = List.filter (fun n -> (get_name n) = name) nodes in
    match ns with
    | h :: _ -> h
    | []     -> failwith (Printf.sprintf "cannot get node %s from graph" name)


  let get_const_value (attr : Symbol.Shape.Type.attr) =
    if (Array.length attr.value > 0) then (
      let v = (attr.value).(0) in
      if (Device.is_arr v) then (
        let arr = Device.value_to_arr v in
        let shp = Device.A.shape arr in
        (* TODO: should be G.A.to_array arr *)
        let float_val = [|0.|] in
        let tensor = make_tftensor ~float_val "DT_FLOAT" shp in
        ATTR_Tensor tensor
      ) else if (Device.is_elt v) then (
        let float_val = [| (Device.value_to_float v) |] in
        let tensor = make_tftensor ~float_val "DT_FLOAT" [||] in
        ATTR_Tensor tensor
      ) else (
        ATTR_Nil
      )
    ) else ATTR_Nil


  let make_index_node idx name =
    let idx_str = Owl_utils_array.to_string ~sep:"," string_of_int idx in
    let tensor_content = Tfgraph_utils.serialise_tensor_content
      "int32" idx_str in
    let tval  = ATTR_Tensor (make_tftensor ~tensor_content "DT_INT32"
      [|Array.length idx|]) in
    TFConst (TFConst.create ~dtype:"DT_INT32" name
      [|Array.length idx|] tval)


  let _make_uniform_initialiser name shp =
    let sname = name ^ "/shape" in
    let shape = make_index_node shp sname in
    (* RandomUniform node *)
    let ru_name = name in
    let ru = TFRandomUniform (TFRandomUniform.create ru_name [|sname|] shp 0 0) in

    (* max const *)
    let mc_name = name ^ "/max" in
    let mc_tensor = ATTR_Tensor (make_tftensor
      ~float_val:[|0.0852802842855|] "DT_FLOAT" [||])
    in
    let mc = TFConst (TFConst.create ~dtype:"DT_FLOAT" mc_name [||] mc_tensor) in

    (* min const *)
    let mic_name = name ^ "/min" in
    let mic_tensor = ATTR_Tensor (make_tftensor
      ~float_val:[|-0.0852802842855|] "DT_FLOAT" [||])
    in
    let mic = TFConst (TFConst.create ~dtype:"DT_FLOAT" mic_name [||] mic_tensor) in

    (* sub *)
    let sub_name = name ^ "/sub" in
    let sub = TFSub (TFSub.create sub_name [|mc_name; mic_name|] [||]) in

    (* mul *)
    let mul_name = name ^ "/mul" in
    let mul = TFMul (TFMul.create mul_name [|ru_name; sub_name|] shp) in

    (* add *)
    let add_name = name ^ "/add" in
    let add = TFAdd (TFAdd.create add_name [|mul_name; mic_name|] shp) in

    [|add; mul; ru; shape; sub; mc; mic|]


  let _make_initialisers (op : Symbol.Shape.Type.op) name =
    match op with
    | Ones shp    ->
      let tvalue = make_tftensor ~float_val:[|1.|] "DT_FLOAT" shp in
      [| TFConst (TFConst.create ~dtype:"DT_FLOAT" name shp (ATTR_Tensor tvalue)) |]
    | Zeros shp   ->
      let tvalue = make_tftensor ~float_val:[|0.|] "DT_FLOAT" shp in
      [| TFConst (TFConst.create ~dtype:"DT_FLOAT" name shp (ATTR_Tensor tvalue)) |]
    | Uniform shp -> _make_uniform_initialiser (name ^ "/random_uniform") shp
    | _           -> failwith "Initialiser not implemented."


  let make_variable_nodes op name out_shp =

    let initialisers = _make_initialisers op name in
    let iname = (get_name initialisers.(0)) in

    let vname = Printf.sprintf "%s/variable" name in

    let rname = name ^ "/read" in
    let read = TFIdentity (TFIdentity.create ~cls:[|vname|] rname [|vname|]
      out_shp "DT_FLOAT")
    in

    let aname = name ^ "/assign" in
    let assign = TFAssign (TFAssign.create ~refv:vname
      ~value:iname aname out_shp "DT_FLOAT")
    in

    (*linked order: var, initialiser, assign, read *)
    let var = TFVariable (TFVariable.create ~linked_nodes:(vname, iname, aname, rname) vname out_shp "DT_FLOAT") in

    (Array.append [|var; read; assign|] initialisers),
    (name, aname)


  let _make_axis_const name axes =
    let aname = name ^ "/reduction_indices" in
    let anode = if (Array.length axes <= 1) then (
      let atensor = ATTR_Tensor (make_tftensor ~int_val:axes "DT_INT32" [||]) in
      TFConst (TFConst.create ~dtype:"DT_INT32" aname [||] atensor)
    ) else (
      make_index_node axes aname
    ) in
    anode, aname


  let make_sum_nodes name inputs shp axes keepdims =
    let anode, aname = _make_axis_const name axes in
    let inputs = Array.append inputs [|aname|] in
    let rnode = TFSum (TFSum.create ~keepdims name inputs shp) in
    [|rnode; anode|], ("", "")


  let make_max_nodes name inputs shp axes keepdims =
    let anode, aname = _make_axis_const name axes in
    let inputs = Array.append inputs [|aname|] in
    let rnode = TFMax (TFMax.create ~keepdims name inputs shp) in
    [|rnode; anode|], ("", "")


  let make_min_nodes name inputs shp axes keepdims =
    let anode, aname = _make_axis_const name axes in
    let inputs = Array.append inputs [|aname|] in
    let rnode = TFMin (TFMin.create ~keepdims name inputs shp) in
    [|rnode; anode|], ("", "")


  let make_log_nodes name inputs shp base =
    let cname = name ^ "/log_base" in
    let ctensor = ATTR_Tensor (make_tftensor ~int_val:[|base|] "DT_INT32" [||]) in
    let cnode = TFConst (TFConst.create ~dtype:"DT_INT32" cname [||] ctensor) in

    let lname2 = name ^ "/log_2" in
    let lnode2 = TFLog (TFLog.create lname2 [|cname|] [||]) in
    let lname1 = name ^ "/log_1" in
    let lnode1 = TFLog (TFLog.create lname1 inputs shp) in

    let dname = name ^ "/div" in
    let dnode = TFDiv (TFDiv.create dname [|lname1; lname2|] shp) in

    [|dnode; lnode1; lnode2; cnode|], (name, dname)


  let _make_stack_for_stridedslice name arr =
    make_index_node arr name


  let make_stridedslice_nodes name inputs out_shp begins ends strides shrink =
    let name0 = name ^ "/stack_0" in
    let name1 = name ^ "/stack_1" in
    let name2 = name ^ "/stack_2" in
    let stack0 = _make_stack_for_stridedslice name0 begins in
    let stack1 = _make_stack_for_stridedslice name1 ends in
    let stack2 = _make_stack_for_stridedslice name2 strides in

    let inputs = Array.append inputs [|name0; name1; name2|] in
    let ss = TFStridedSlice (TFStridedSlice.create name inputs out_shp
      0 0 0 0 shrink) in
    [|ss; stack0; stack1; stack2|], ("", "")


  let make_reshape_nodes name inputs shp =
    let sname = name ^ "/shape" in
    let snode = make_index_node shp sname in

    let inputs = Array.append inputs [|sname|] in
    let rnode = TFReshape (TFReshape.create name inputs shp) in
    [|rnode; snode|], ("", "")


  let _get_input_shape owlnode =
    let inode = (Owl_graph.parents owlnode).(0) in
    let iattr : Symbol.Shape.Type.attr = Owl_graph.attr inode in
    match iattr.shape.(0) with
    | Some s -> s
    | None   -> failwith "Owlnode output shape cannot be None"


  let make_l2norm_sqr_nodes name inputs inp_shp out_shp axes keepdims =
    let sqrname = name ^ "/square" in
    let sqrnode = TFSquare (TFSquare.create sqrname inputs inp_shp) in
    let sumnodes, _ = make_sum_nodes name [|sqrname|] out_shp axes keepdims in
    (Array.append sumnodes [|sqrnode|]), ("", "")


  let make_l2norm_nodes name inputs inp_shp out_shp axes keepdims =
    let sqrnodes, (_, uname) = make_l2norm_sqr_nodes name inputs
      inp_shp out_shp axes keepdims in
    let sname = name ^ "/sqrt" in
    let snode = TFSqrt (TFSqrt.create sname [|uname|] out_shp) in
    (Array.append [|snode|] sqrnodes), (name, sname)


  let make_l1norm_nodes name inputs inp_shp out_shp axes keepdims =
    let aname = name ^ "/abs" in
    let anode = TFAbs (TFAbs.create aname inputs inp_shp) in

    let sumname = name ^ "/sum" in
    let sumnodes, _ = make_sum_nodes sumname [|aname|] out_shp axes keepdims in
    (Array.append sumnodes [|anode|]), (name, sumname)


  let make_conv2dbackinput_nodes name inputs out_shp padding strides =
    let sname = name ^ "/output_shape" in
    let snode = make_index_node out_shp sname in
    let strides = [|1; strides.(0); strides.(1); 1|] in
    let inputs = Array.append inputs [|sname|] in
    let cnode = TFConv2DBackInput (TFConv2DBackInput.create name
      inputs out_shp padding strides) in
    [|cnode; snode|], ("", "")


  let make_conv2dbackkernel_nodes name inputs out_shp padding strides =
    let sname = name ^ "/filter_sizes" in
    let snode = make_index_node out_shp sname in
    let strides = [|1; strides.(0); strides.(1); 1|] in
    let inputs = Array.append inputs [|sname|] in
    let cnode = TFConv2DBackFilter (TFConv2DBackFilter.create name
      inputs out_shp padding strides) in
    [|cnode; snode|], ("", "")


  let make_ofarray_2d_nodes name inputs out_shp shp =
    if (Array.length shp = 1) then (
      [| TFPack (TFPack.create name inputs out_shp 0) |], ("", "")
    ) else if (Array.length shp = 2) then (
      let a = shp.(0) in
      let b = shp.(1) in
      let nodes = Array.make a (TFNoop (TFNoop.create "" [||])) in
      let names = Array.make a "" in
      for i = 0 to a - 1 do
        let nname = Printf.sprintf "%s-%d" name i in
        let ninpt = Array.sub inputs (i * b) b in
        nodes.(i) <- TFPack (TFPack.create nname ninpt [|out_shp.(1)|] 0);
        names.(i) <- nname
      done;
      let nnode2d = TFPack (TFPack.create name names out_shp 1) in
      (Array.append [|nnode2d|] nodes), ("", "")
    ) else (
      failwith "OfArray: dimensions larger than 2 is not supported yet"
    )


  let make_transpose_nodes name inputs out_shp perm =
    let pname = name ^ "/perm" in
    let pnode = make_index_node perm pname in
    let tnode = TFTranspose (TFTranspose.create name [|inputs.(0); pname|] out_shp) in
    [|tnode; pnode|], ("", "")


  let make_trace_nodes name inputs out_shp input_shp =
    let dname = name ^ "/matrixDiagPart" in
    let l = Array.length input_shp in
    assert(l >= 2);
    let last_dim = Pervasives.min input_shp.(l-1) input_shp.(l-2) in
    let dshp = Array.copy input_shp in
    dshp.(l-2) <- last_dim;
    let dshp = Array.sub dshp 0 (l - 1) in
    let dnode = TFMatrixDiagPart (TFMatrixDiagPart.create dname inputs dshp) in

    let rname = name ^ "/reduction_indices" in
    let rval = ATTR_Tensor (make_tftensor ~int_val:[|-1|] "DT_INT32" [|1|]) in
    let rnode = TFConst (TFConst.create ~dtype:"DT_INT32" rname [|1|] rval) in

    let snode = TFSum (TFSum.create ~keepdims:false name [|dname; rname|] out_shp) in

    [|snode; rnode; dnode|], ("", "")


  let make_concat_nodes name inputs out_shp axis =
    let aname = name ^ "/axis" in
    let aval  = ATTR_Tensor (make_tftensor ~int_val:[|axis|] "DT_INT32" [||]) in
    let anode = TFConst (TFConst.create ~dtype:"DT_INT32" aname [||] aval) in

    let cinpt = Array.append inputs [|aname|] in
    let cnode = TFConcat (TFConcat.create name cinpt out_shp) in

    [|cnode; anode|], ("", "")


  let make_tile_nodes name inputs out_shp axes =
    let aname = name ^ "/axis" in
    let anode = make_index_node axes aname in
    let tinpt = Array.append inputs [|aname|] in
    let tnode = TFTile (TFTile.create name tinpt out_shp) in
    [|tnode; anode|], ("", "")


  (* The logic of how one owl node turned into multiple tfnodes is implemented
   * here.
   * Currently return node array and "name_update" : string * string; meaning,
   * whoever uses me as his input, now change it to one of my subnodes.
   * About the `attr.shape.(0)` and `(attr.value).(0)` below, currently only
   * `draw` operation in owl CGraph returns two outputs, so I'll stick with
   * this tmp solution for now.
   *)
  let make_tfnodes _tfgraph node =
    let name = Owl_graph.name node in
    let attr : Symbol.Shape.Type.attr = Owl_graph.attr node in
    let inputs = Array.map (fun n ->
      Owl_graph.name n
    ) (Owl_graph.parents node)
    in
    (* TODO: only uses the first output currently *)
    let out_shp = attr.shape.(0) in
    let out_shp =
      match out_shp with
      | Some s -> s
      | None   -> [||]
    in
    match attr.op with
    | Abs                     -> [| TFAbs (TFAbs.create name inputs out_shp)|], ("", "")
    | Scalar_Abs              -> [| TFAbs (TFAbs.create name inputs out_shp)|], ("", "")
    | Neg                     -> [| TFNeg (TFNeg.create name inputs out_shp)|], ("", "")
    | Scalar_Neg              -> [| TFNeg (TFNeg.create name inputs out_shp)|], ("", "")
    | Exp                     -> [| TFExp (TFExp.create name inputs out_shp)|], ("", "")
    | Scalar_Exp              -> [| TFExp (TFExp.create name inputs out_shp)|], ("", "")
    | Log                     -> [| TFLog (TFLog.create name inputs out_shp)|], ("", "")
    | Log2                    -> make_log_nodes name inputs out_shp 2
    | Log10                   -> make_log_nodes name inputs out_shp 10
    | Scalar_Log              -> [| TFLog (TFLog.create name inputs out_shp)|], ("", "")
    | Scalar_Log2             -> make_log_nodes name inputs out_shp 2
    | Scalar_Log10            -> make_log_nodes name inputs out_shp 10
    | Sqr                     -> [| TFSquare (TFSquare.create name inputs out_shp)|], ("", "")
    | Scalar_Sqr              -> [| TFSquare (TFSquare.create name inputs out_shp)|], ("", "")
    | Sqrt                    -> [| TFSqrt (TFSqrt.create name inputs out_shp)|], ("", "")
    | Scalar_Sqrt             -> [| TFSqrt (TFSqrt.create name inputs out_shp)|], ("", "")
    | Sin                     -> [| TFSin (TFSin.create name inputs out_shp)|], ("", "")
    | Cos                     -> [| TFCos (TFCos.create name inputs out_shp)|], ("", "")
    | Tan                     -> [| TFTan (TFTan.create name inputs out_shp)|], ("", "")
    | Sinh                    -> [| TFSinh (TFSinh.create name inputs out_shp)|], ("", "")
    | Cosh                    -> [| TFCosh (TFCosh.create name inputs out_shp)|], ("", "")
    | Tanh                    -> [| TFTanh (TFTanh.create name inputs out_shp)|], ("", "")
    | Asin                    -> [| TFAsin (TFAsin.create name inputs out_shp)|], ("", "")
    | Acos                    -> [| TFAcos (TFAcos.create name inputs out_shp)|], ("", "")
    | Atan                    -> [| TFAtan (TFAtan.create name inputs out_shp)|], ("", "")
    | Asinh                   -> [| TFAsinh (TFAsinh.create name inputs out_shp)|], ("", "")
    | Acosh                   -> [| TFCosh (TFCosh.create name inputs out_shp)|], ("", "")
    | Atanh                   -> [| TFAtanh (TFAtanh.create name inputs out_shp)|], ("", "")
    | Scalar_Sin              -> [| TFSin (TFSin.create name inputs out_shp)|], ("", "")
    | Scalar_Cos              -> [| TFCos (TFCos.create name inputs out_shp)|], ("", "")
    | Scalar_Tan              -> [| TFTan (TFTan.create name inputs out_shp)|], ("", "")
    | Scalar_Sinh             -> [| TFSinh (TFSinh.create name inputs out_shp)|], ("", "")
    | Scalar_Cosh             -> [| TFCosh (TFCosh.create name inputs out_shp)|], ("", "")
    | Scalar_Tanh             -> [| TFTanh (TFTanh.create name inputs out_shp)|], ("", "")
    | Scalar_Asin             -> [| TFAsin (TFAsin.create name inputs out_shp)|], ("", "")
    | Scalar_Acos             -> [| TFAcos (TFAcos.create name inputs out_shp)|], ("", "")
    | Scalar_Atan             -> [| TFAtan (TFAtan.create name inputs out_shp)|], ("", "")
    | Scalar_Asinh            -> [| TFAsinh (TFAsinh.create name inputs out_shp)|], ("", "")
    | Scalar_Acosh            -> [| TFCosh (TFCosh.create name inputs out_shp)|], ("", "")
    | Scalar_Atanh            -> [| TFAtanh (TFAtanh.create name inputs out_shp)|], ("", "")
    | Sigmoid                 -> [| TFSigmoid (TFSigmoid.create name inputs out_shp)|], ("", "")
    | Scalar_Sigmoid          -> [| TFSigmoid (TFSigmoid.create name inputs out_shp)|], ("", "")
    | Dot (a, b, _, _)        -> [| TFMatMul (TFMatMul.create name inputs out_shp a b) |], ("", "")
    | Add                     -> [| TFAdd (TFAdd.create name inputs out_shp) |], ("", "")
    | ScalarAdd               -> [| TFAdd (TFAdd.create name inputs out_shp) |], ("", "")
    | Scalar_Add              -> [| TFAdd (TFAdd.create name inputs out_shp) |], ("", "")
    | AddScalar               -> [| TFAdd (TFAdd.create name inputs out_shp) |], ("", "")
    | Sub                     -> [| TFSub (TFSub.create name inputs out_shp) |], ("", "")
    | ScalarSub               -> [| TFSub (TFSub.create name inputs out_shp) |], ("", "")
    | SubScalar               -> [| TFSub (TFSub.create name inputs out_shp) |], ("", "")
    | Mul                     -> [| TFMul (TFMul.create name inputs out_shp) |], ("", "")
    | MulScalar               -> [| TFMul (TFMul.create name inputs out_shp) |], ("", "")
    | ScalarMul               -> [| TFMul (TFMul.create name inputs out_shp) |], ("", "")
    | Div                     -> [| TFDiv (TFDiv.create name inputs out_shp) |], ("", "")
    | DivScalar               -> [| TFDiv (TFDiv.create name inputs out_shp) |], ("", "")
    | ScalarDiv               -> [| TFDiv (TFDiv.create name inputs out_shp) |], ("", "")
    | Scalar_Div              -> [| TFDiv (TFDiv.create name inputs out_shp) |], ("", "")
    | Pow                     -> [| TFPow (TFPow.create name inputs out_shp) |], ("", "")
    | Scalar_Pow              -> [| TFPow (TFPow.create name inputs out_shp) |], ("", "")
    | PowScalar               -> [| TFPow (TFPow.create name inputs out_shp) |], ("", "")
    | Relu                    -> [| TFRelu (TFRelu.create name inputs out_shp) |], ("", "")
    | Scalar_Relu             -> [| TFRelu (TFRelu.create name inputs out_shp) |], ("", "")
    | Transpose perm          -> make_transpose_nodes name inputs out_shp perm
    | Inv                     -> [| TFMatrixInverse (TFMatrixInverse.create name inputs out_shp) |], ("", "")
    | Trace                   ->
      let input_shp = _get_input_shape node in
      make_trace_nodes name inputs out_shp input_shp
    | L2NormSqr'              ->
      let input_shp = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shp - 1) in
      make_l2norm_sqr_nodes name inputs input_shp out_shp axes false
    | L2norm'                 ->
      let input_shp = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shp - 1) in
      make_l2norm_nodes name inputs input_shp out_shp axes false
    | L1norm'                 ->
      let input_shp = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shp - 1) in
      make_l1norm_nodes name inputs input_shp out_shp axes false
    | Conv2d (p, s)           ->
      let s = [|1; s.(0); s.(1); 1|] in
      [| TFConv2D (TFConv2D.create name inputs out_shp p s) |], ("", "")
    | Conv2dBackwardKernel s  -> make_conv2dbackkernel_nodes name inputs out_shp Owl_types_common.SAME s
    | Conv2dBackwardInput s   -> make_conv2dbackinput_nodes name inputs out_shp Owl_types_common.SAME s
    | TransposeConv2d (p, s)  -> make_conv2dbackinput_nodes name inputs out_shp p s
    | DilatedConv2d (p, s, d) ->
      let s = [|1; s.(0); s.(1); 1|] in
      let d = [|1; d.(0); d.(1); 1|] in
      [| TFConv2D (TFConv2D.create ~dilations:d name inputs out_shp p s) |], ("", "")
    | MaxPool1d (p, s, k)     ->
      let s = [|1; s.(0); 1|] in
      let k = [|1; k.(0); 1|] in
      [| TFMaxPool (TFMaxPool.create name inputs out_shp p s k) |], ("", "")
    | AvgPool1d (p, s, k)     ->
      let s = [|1; s.(0); 1|] in
      let k = [|1; k.(0); 1|] in
      [| TFAvgPool (TFAvgPool.create name inputs out_shp p s k) |], ("", "")
    | MaxPool2d (p, s, k)     ->
      let s = [|1; s.(0); s.(1); 1|] in
      let k = [|1; k.(0); k.(1); 1|] in
      [| TFMaxPool (TFMaxPool.create name inputs out_shp p s k) |], ("", "")
    | AvgPool2d (p, s, k)     ->
      let s = [|1; s.(0); s.(1); 1|] in
      let k = [|1; k.(0); k.(1); 1|] in
      [| TFAvgPool (TFAvgPool.create name inputs out_shp p s k) |], ("", "")
    | Sum a                   -> make_sum_nodes name inputs out_shp [|a|] true
    | SumReduce a             -> make_sum_nodes name inputs out_shp a true
    | Sum'                    ->
      let input_shape = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shape - 1) in
      make_sum_nodes name inputs out_shp axes false
    | Max a                   -> make_max_nodes name inputs out_shp [|a|] true
    | Max'                    ->
      let input_shape = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shape - 1) in
      make_max_nodes name inputs out_shp axes false
    | Min a                   -> make_min_nodes name inputs out_shp [|a|] true
    | Min'                    ->
      let input_shape = _get_input_shape node in
      let axes = Owl_utils_array.range 0 (Array.length input_shape - 1) in
      make_min_nodes name inputs out_shp axes false
    | Concatenate axis        -> make_concat_nodes name inputs out_shp axis
    | Tile axes               -> make_tile_nodes name inputs out_shp axes
    | OfArray shp             -> make_ofarray_2d_nodes name inputs out_shp shp
    | Var                     -> [| TFPlaceholder (TFPlaceholder.create name out_shp) |], ("", "")
    | Const                   ->
      let value = get_const_value attr in
      [| TFConst (TFConst.create ~dtype:"DT_FLOAT" name out_shp value) |], ("", "")
    | Reshape s               -> make_reshape_nodes name inputs s
    | Ones _                  -> make_variable_nodes attr.op name out_shp
    | Zeros _                 -> make_variable_nodes attr.op name out_shp
    | Uniform _               -> make_variable_nodes attr.op name out_shp
    | Get i                   ->
      let b = i in let e = i in
      let len = Array.length i in
      let s = Array.make len 1 in
      let shinrk_mask = (2. ** (float_of_int len) |> int_of_float) - 1 in
      make_stridedslice_nodes name inputs out_shp b e s shinrk_mask
    | GetSlice i              ->
      let input_shp = _get_input_shape node in
      let b, e, s = Tfgraph_utils.get_slice_param i input_shp in
      make_stridedslice_nodes name inputs out_shp b e s 0
    | _                       -> let err = Printf.sprintf "unsupported operation: %s" (Symbol.op_to_str attr.op) in failwith err


  let expand_tfgraph tfgraph owlnode =
    let tfnodes, name_update = make_tfnodes tfgraph owlnode in
    add_tfnodes tfgraph tfnodes name_update

end
