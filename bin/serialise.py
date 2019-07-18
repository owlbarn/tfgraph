#!/usr/bin/env python

import variable_pb2
import sys

variable = variable_pb2.VariableDef()
variable.variable_name = sys.argv[1]
variable.initial_value_name = sys.argv[2]
variable.initializer_name = sys.argv[3]
variable.snapshot_name = sys.argv[4]
variable.is_resource = False
variable.trainable = True
#variable.synchronization = 0
#variable.aggregation = 0

#save_variable = variable.save_slice_info_def
#save_variable.full_name = "shit"
#save_variable.full_shape.extend([1,2,3])

print(variable.SerializeToString())
