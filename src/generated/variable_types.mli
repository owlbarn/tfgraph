(** variable.proto Types *)



(** {2 Types} *)

type variable_synchronization =
  | Variable_synchronization_auto 
  | Variable_synchronization_none 
  | Variable_synchronization_on_write 
  | Variable_synchronization_on_read 

type variable_aggregation =
  | Variable_aggregation_none 
  | Variable_aggregation_sum 
  | Variable_aggregation_mean 
  | Variable_aggregation_only_first_replica 

type save_slice_info_def = {
  full_name : string;
  full_shape : int64 list;
  var_offset : int64 list;
  var_shape : int64 list;
}

type variable_def = {
  variable_name : string;
  initial_value_name : string;
  initializer_name : string;
  snapshot_name : string;
  save_slice_info_def : save_slice_info_def option;
  is_resource : bool;
  trainable : bool;
  synchronization : variable_synchronization;
  aggregation : variable_aggregation;
}


(** {2 Default values} *)

val default_variable_synchronization : unit -> variable_synchronization
(** [default_variable_synchronization ()] is the default value for type [variable_synchronization] *)

val default_variable_aggregation : unit -> variable_aggregation
(** [default_variable_aggregation ()] is the default value for type [variable_aggregation] *)

val default_save_slice_info_def : 
  ?full_name:string ->
  ?full_shape:int64 list ->
  ?var_offset:int64 list ->
  ?var_shape:int64 list ->
  unit ->
  save_slice_info_def
(** [default_save_slice_info_def ()] is the default value for type [save_slice_info_def] *)

val default_variable_def : 
  ?variable_name:string ->
  ?initial_value_name:string ->
  ?initializer_name:string ->
  ?snapshot_name:string ->
  ?save_slice_info_def:save_slice_info_def option ->
  ?is_resource:bool ->
  ?trainable:bool ->
  ?synchronization:variable_synchronization ->
  ?aggregation:variable_aggregation ->
  unit ->
  variable_def
(** [default_variable_def ()] is the default value for type [variable_def] *)
