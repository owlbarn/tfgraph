(** variable.proto Binary Encoding *)


(** {2 Protobuf Encoding} *)

val encode_variable_synchronization : Variable_types.variable_synchronization -> Pbrt.Encoder.t -> unit
(** [encode_variable_synchronization v encoder] encodes [v] with the given [encoder] *)

val encode_variable_aggregation : Variable_types.variable_aggregation -> Pbrt.Encoder.t -> unit
(** [encode_variable_aggregation v encoder] encodes [v] with the given [encoder] *)

val encode_save_slice_info_def : Variable_types.save_slice_info_def -> Pbrt.Encoder.t -> unit
(** [encode_save_slice_info_def v encoder] encodes [v] with the given [encoder] *)

val encode_variable_def : Variable_types.variable_def -> Pbrt.Encoder.t -> unit
(** [encode_variable_def v encoder] encodes [v] with the given [encoder] *)


(** {2 Protobuf Decoding} *)

val decode_variable_synchronization : Pbrt.Decoder.t -> Variable_types.variable_synchronization
(** [decode_variable_synchronization decoder] decodes a [variable_synchronization] value from [decoder] *)

val decode_variable_aggregation : Pbrt.Decoder.t -> Variable_types.variable_aggregation
(** [decode_variable_aggregation decoder] decodes a [variable_aggregation] value from [decoder] *)

val decode_save_slice_info_def : Pbrt.Decoder.t -> Variable_types.save_slice_info_def
(** [decode_save_slice_info_def decoder] decodes a [save_slice_info_def] value from [decoder] *)

val decode_variable_def : Pbrt.Decoder.t -> Variable_types.variable_def
(** [decode_variable_def decoder] decodes a [variable_def] value from [decoder] *)
