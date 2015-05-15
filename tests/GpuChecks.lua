--[[

  Image Captioning using an LSTM and a softmax for the language model

--]]

local GpuChecks = torch.class('imagelstm.GpuChecks')

function GradChecks:__init(config)
  require('cutorch')
  require('cunn')
end

function GradChecks:check_gpu()
  inputs = torch.rand(1000)
  net = nn.Linear(1000, 5000)

  cpu_time = check_cpu_speed(inputs, net)
  gpu_time = check_gpu_speed(inputs, net)

  print("Cpu time is ")
  print(cpu_time)

  print ("Gpu time is")
  print(gpu_time)
end

-- Checks how fast CPU speed is for neural net
function GradChecks:check_cpu_speed(inputs, nnet)
  local start_time = sys.clock()
  for i in 1, 1000 do
    nnet:forward(inputs)
  end
  local end_time = sys.clock()
  return (end_time - start_time) / 1000
end

-- Checks how fast GPU speed is for neural net
function GradChecks:check_gpu_speed(inputs, nnet)
  inputs:cuda()
  nnet:cuda()
  local start_time = sys.clock()
  for i in 1, 1000 do
    nnet:forward(inputs)
  end
  local end_time = sys.clock()
  return (end_time - start_time) / 1000
end



