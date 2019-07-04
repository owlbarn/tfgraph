[@@@ocaml.warning "-27-30-39"]

type save_slice_info_def_mutable = {
  mutable full_name : string;
  mutable full_shape : int64 list;
  mutable var_offset : int64 list;
  mutable var_shape : int64 list;
}

let default_save_slice_info_def_mutable () : save_slice_info_def_mutable = {
  full_name = "";
  full_shape = [];
  var_offset = [];
  var_shape = [];
}

type variable_def_mutable = {
  mutable variable_name : string;
  mutable initial_value_name : string;
  mutable initializer_name : string;
  mutable snapshot_name : string;
  mutable save_slice_info_def : Variable_types.save_slice_info_def option;
  mutable is_resource : bool;
  mutable trainable : bool;
  mutable synchronization : Variable_types.variable_synchronization;
  mutable aggregation : Variable_types.variable_aggregation;
}

let default_variable_def_mutable () : variable_def_mutable = {
  variable_name = "";
  initial_value_name = "";
  initializer_name = "";
  snapshot_name = "";
  save_slice_info_def = None;
  is_resource = false;
  trainable = false;
  synchronization = Variable_types.default_variable_synchronization ();
  aggregation = Variable_types.default_variable_aggregation ();
}


let rec decode_variable_synchronization d = 
  match Pbrt.Decoder.int_as_varint d with
  | 0 -> (Variable_types.Variable_synchronization_auto:Variable_types.variable_synchronization)
  | 1 -> (Variable_types.Variable_synchronization_none:Variable_types.variable_synchronization)
  | 2 -> (Variable_types.Variable_synchronization_on_write:Variable_types.variable_synchronization)
  | 3 -> (Variable_types.Variable_synchronization_on_read:Variable_types.variable_synchronization)
  | _ -> Pbrt.Decoder.malformed_variant "variable_synchronization"

let rec decode_variable_aggregation d = 
  match Pbrt.Decoder.int_as_varint d with
  | 0 -> (Variable_types.Variable_aggregation_none:Variable_types.variable_aggregation)
  | 1 -> (Variable_types.Variable_aggregation_sum:Variable_types.variable_aggregation)
  | 2 -> (Variable_types.Variable_aggregation_mean:Variable_types.variable_aggregation)
  | 3 -> (Variable_types.Variable_aggregation_only_first_replica:Variable_types.variable_aggregation)
  | _ -> Pbrt.Decoder.malformed_variant "variable_aggregation"

let rec decode_save_slice_info_def d =
  let v = default_save_slice_info_def_mutable () in
  let continue__= ref true in
  while !continue__ do
    match Pbrt.Decoder.key d with
    | None -> (
      v.var_shape <- List.rev v.var_shape;
      v.var_offset <- List.rev v.var_offset;
      v.full_shape <- List.rev v.full_shape;
    ); continue__ := false
    | Some (1, Pbrt.Bytes) -> begin
      v.full_name <- Pbrt.Decoder.string d;
    end
    | Some (1, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(save_slice_info_def), field(1)" pk
    | Some (2, Pbrt.Varint) -> begin
      v.full_shape <- (Pbrt.Decoder.int64_as_varint d) :: v.full_shape;
    end
    | Some (2, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(save_slice_info_def), field(2)" pk
    | Some (3, Pbrt.Varint) -> begin
      v.var_offset <- (Pbrt.Decoder.int64_as_varint d) :: v.var_offset;
    end
    | Some (3, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(save_slice_info_def), field(3)" pk
    | Some (4, Pbrt.Varint) -> begin
      v.var_shape <- (Pbrt.Decoder.int64_as_varint d) :: v.var_shape;
    end
    | Some (4, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(save_slice_info_def), field(4)" pk
    | Some (_, payload_kind) -> Pbrt.Decoder.skip d payload_kind
  done;
  ({
    Variable_types.full_name = v.full_name;
    Variable_types.full_shape = v.full_shape;
    Variable_types.var_offset = v.var_offset;
    Variable_types.var_shape = v.var_shape;
  } : Variable_types.save_slice_info_def)

let rec decode_variable_def d =
  let v = default_variable_def_mutable () in
  let continue__= ref true in
  while !continue__ do
    match Pbrt.Decoder.key d with
    | None -> (
    ); continue__ := false
    | Some (1, Pbrt.Bytes) -> begin
      v.variable_name <- Pbrt.Decoder.string d;
    end
    | Some (1, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(1)" pk
    | Some (6, Pbrt.Bytes) -> begin
      v.initial_value_name <- Pbrt.Decoder.string d;
    end
    | Some (6, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(6)" pk
    | Some (2, Pbrt.Bytes) -> begin
      v.initializer_name <- Pbrt.Decoder.string d;
    end
    | Some (2, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(2)" pk
    | Some (3, Pbrt.Bytes) -> begin
      v.snapshot_name <- Pbrt.Decoder.string d;
    end
    | Some (3, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(3)" pk
    | Some (4, Pbrt.Bytes) -> begin
      v.save_slice_info_def <- Some (decode_save_slice_info_def (Pbrt.Decoder.nested d));
    end
    | Some (4, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(4)" pk
    | Some (5, Pbrt.Varint) -> begin
      v.is_resource <- Pbrt.Decoder.bool d;
    end
    | Some (5, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(5)" pk
    | Some (7, Pbrt.Varint) -> begin
      v.trainable <- Pbrt.Decoder.bool d;
    end
    | Some (7, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(7)" pk
    | Some (8, Pbrt.Varint) -> begin
      v.synchronization <- decode_variable_synchronization d;
    end
    | Some (8, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(8)" pk
    | Some (9, Pbrt.Varint) -> begin
      v.aggregation <- decode_variable_aggregation d;
    end
    | Some (9, pk) -> 
      Pbrt.Decoder.unexpected_payload "Message(variable_def), field(9)" pk
    | Some (_, payload_kind) -> Pbrt.Decoder.skip d payload_kind
  done;
  ({
    Variable_types.variable_name = v.variable_name;
    Variable_types.initial_value_name = v.initial_value_name;
    Variable_types.initializer_name = v.initializer_name;
    Variable_types.snapshot_name = v.snapshot_name;
    Variable_types.save_slice_info_def = v.save_slice_info_def;
    Variable_types.is_resource = v.is_resource;
    Variable_types.trainable = v.trainable;
    Variable_types.synchronization = v.synchronization;
    Variable_types.aggregation = v.aggregation;
  } : Variable_types.variable_def)

let rec encode_variable_synchronization (v:Variable_types.variable_synchronization) encoder =
  match v with
  | Variable_types.Variable_synchronization_auto -> Pbrt.Encoder.int_as_varint (0) encoder
  | Variable_types.Variable_synchronization_none -> Pbrt.Encoder.int_as_varint 1 encoder
  | Variable_types.Variable_synchronization_on_write -> Pbrt.Encoder.int_as_varint 2 encoder
  | Variable_types.Variable_synchronization_on_read -> Pbrt.Encoder.int_as_varint 3 encoder

let rec encode_variable_aggregation (v:Variable_types.variable_aggregation) encoder =
  match v with
  | Variable_types.Variable_aggregation_none -> Pbrt.Encoder.int_as_varint (0) encoder
  | Variable_types.Variable_aggregation_sum -> Pbrt.Encoder.int_as_varint 1 encoder
  | Variable_types.Variable_aggregation_mean -> Pbrt.Encoder.int_as_varint 2 encoder
  | Variable_types.Variable_aggregation_only_first_replica -> Pbrt.Encoder.int_as_varint 3 encoder

let rec encode_save_slice_info_def (v:Variable_types.save_slice_info_def) encoder = 
  Pbrt.Encoder.key (1, Pbrt.Bytes) encoder; 
  Pbrt.Encoder.string v.Variable_types.full_name encoder;
  List.iter (fun x -> 
    Pbrt.Encoder.key (2, Pbrt.Varint) encoder; 
    Pbrt.Encoder.int64_as_varint x encoder;
  ) v.Variable_types.full_shape;
  List.iter (fun x -> 
    Pbrt.Encoder.key (3, Pbrt.Varint) encoder; 
    Pbrt.Encoder.int64_as_varint x encoder;
  ) v.Variable_types.var_offset;
  List.iter (fun x -> 
    Pbrt.Encoder.key (4, Pbrt.Varint) encoder; 
    Pbrt.Encoder.int64_as_varint x encoder;
  ) v.Variable_types.var_shape;
  ()

let rec encode_variable_def (v:Variable_types.variable_def) encoder = 
  Pbrt.Encoder.key (1, Pbrt.Bytes) encoder; 
  Pbrt.Encoder.string v.Variable_types.variable_name encoder;
  Pbrt.Encoder.key (6, Pbrt.Bytes) encoder; 
  Pbrt.Encoder.string v.Variable_types.initial_value_name encoder;
  Pbrt.Encoder.key (2, Pbrt.Bytes) encoder; 
  Pbrt.Encoder.string v.Variable_types.initializer_name encoder;
  Pbrt.Encoder.key (3, Pbrt.Bytes) encoder; 
  Pbrt.Encoder.string v.Variable_types.snapshot_name encoder;
  begin match v.Variable_types.save_slice_info_def with
  | Some x -> 
    Pbrt.Encoder.key (4, Pbrt.Bytes) encoder; 
    Pbrt.Encoder.nested (encode_save_slice_info_def x) encoder;
  | None -> ();
  end;
  Pbrt.Encoder.key (5, Pbrt.Varint) encoder; 
  Pbrt.Encoder.bool v.Variable_types.is_resource encoder;
  Pbrt.Encoder.key (7, Pbrt.Varint) encoder; 
  Pbrt.Encoder.bool v.Variable_types.trainable encoder;
  Pbrt.Encoder.key (8, Pbrt.Varint) encoder; 
  encode_variable_synchronization v.Variable_types.synchronization encoder;
  Pbrt.Encoder.key (9, Pbrt.Varint) encoder; 
  encode_variable_aggregation v.Variable_types.aggregation encoder;
  ()
