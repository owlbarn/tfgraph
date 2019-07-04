[@@@ocaml.warning "-27-30-39"]


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

let rec default_variable_synchronization () = (Variable_synchronization_auto:variable_synchronization)

let rec default_variable_aggregation () = (Variable_aggregation_none:variable_aggregation)

let rec default_save_slice_info_def 
  ?full_name:((full_name:string) = "")
  ?full_shape:((full_shape:int64 list) = [])
  ?var_offset:((var_offset:int64 list) = [])
  ?var_shape:((var_shape:int64 list) = [])
  () : save_slice_info_def  = {
  full_name;
  full_shape;
  var_offset;
  var_shape;
}

let rec default_variable_def 
  ?variable_name:((variable_name:string) = "")
  ?initial_value_name:((initial_value_name:string) = "")
  ?initializer_name:((initializer_name:string) = "")
  ?snapshot_name:((snapshot_name:string) = "")
  ?save_slice_info_def:((save_slice_info_def:save_slice_info_def option) = None)
  ?is_resource:((is_resource:bool) = false)
  ?trainable:((trainable:bool) = false)
  ?synchronization:((synchronization:variable_synchronization) = default_variable_synchronization ())
  ?aggregation:((aggregation:variable_aggregation) = default_variable_aggregation ())
  () : variable_def  = {
  variable_name;
  initial_value_name;
  initializer_name;
  snapshot_name;
  save_slice_info_def;
  is_resource;
  trainable;
  synchronization;
  aggregation;
}
