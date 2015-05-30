--[[

  Add layer: adds image features and word embeddings together
  at first time step, then just word embeddings
--]]

local SingleAddLayer = torch.class('imagelstm.SingleAddLayer')

function SingleAddLayer:__init(config)
   self.gpu_mode = config.gpu_mode or false
   self.emb_learning_rate  = config.emb_learning_rate or 0.01
   self.emb_dim = config.emb_dim or 300
   self.image_dim = config.image_dim or 1024
   self.vocab_size = config.num_classes or 300
   if config.emb_vecs ~= nil then
    self.vocab_size = config.emb_vecs:size(1)
   end
   self.emb = nn.LookupTable(self.vocab_size, self.emb_dim)

   -- image feature embedding
   self.image_emb = nn.Linear(self.image_dim, self.emb_dim)

   -- Do a linear combination of image and word features
   local x1 = nn.Identity(self.emb_dim)()
   local x2 = nn.Identity(self.emb_dim)()
   local a = imagelstm.CRowSingleTable()({x1, x2})
  
   self.lstm_emb = nn.gModule({x1, x2}, {a})

   local modules = nn.Parallel()
    :add(self.image_emb)
    :add(self.emb)

   self.params, self.grad_params = modules:getParameters()

   if self.gpu_mode then 
    self:set_gpu_mode()
   end

   if config.emb_vecs ~= nil then
    self.emb.weight:copy(config.emb_vecs)
   end

   -- Copy the image embedding vectors
   if config.combine_weights ~= nil then
     print("Copying combine weights")
     self.params:copy(config.combine_weights)
   end

end

-- Sets gpu mode
function SingleAddLayer:set_gpu_mode()
  self.image_emb:cuda()
  self.emb:cuda()
  self.lstm_emb:cuda()
  self.params:cuda()
end

-- Returns the trainable modules of this layer
function SingleAddLayer:getModules() 
  return {self.image_emb, self.emb}
end

-- Returns all of the weights of this module
function SingleAddLayer:getWeights()
  return self.params
end

-- Does a single forward step of add layer
-- Num_iter: only for beam search since we forward image features on first index
function SingleAddLayer:forward(word_indeces, image_feats, num_iter)
    self.text_inputs = self.emb:forward(word_indeces)
    self.image_inputs = self.image_emb:forward(image_feats)
    self.inputs = self.lstm_emb:forward({self.text_inputs, self.image_inputs})

    if num_iter ~= nil and num_iter > 0 then
      return self.text_inputs
    else
      return self.inputs
    end
end

function SingleAddLayer:backward(word_indices, image_feats, grads)
  -- backprop the gradients through the linear combination step
  local input_emb_grads = self.lstm_emb:backward({self.text_inputs, self.image_inputs}, grads)
  local emb_grads = input_emb_grads[1]
  local image_grads = input_emb_grads[2]

  self.emb:backward(word_indices, emb_grads)
  self.image_emb:backward(image_feats, image_grads)
end

-- zeros out the gradients
function SingleAddLayer:zeroGradParameters() 
  self.image_emb:zeroGradParameters()
  self.emb:zeroGradParameters()
  self.lstm_emb:zeroGradParameters()
end

function SingleAddLayer:normalizeGrads(batch_size)
  self.image_emb.gradWeight:div(batch_size)
  self.emb.gradWeight:div(batch_size)
end

function SingleAddLayer:getOutputSize()
  return self.emb_dim
end

function SingleAddLayer:getParameters()
  return self.params, self.grad_params
end


