--[[

  Concat layer: concatenates projected image features and word embeddings together
  after projecting image features to some dimension

--]]

local ConcatLayer = torch.class('imagelstm.ConcatLayer')

function ConcatLayer:__init(config)
   self.gpu_mode = config.gpu_mode or false
   self.emb_dim = config.emb_dim or 300
   self.image_dim = config.image_dim or 1024
   self.vocab_size = config.num_classes or 300
   if config.emb_vecs ~= nil then
    self.vocab_size = config.emb_vecs:size(1)
   end

   self.emb = nn.LookupTable(self.vocab_size, self.emb_dim)

   -- image feature embedding
   self.image_emb = nn.Linear(self.image_dim, self.emb_dim)

   -- image feature embedding
   self.combine_model = imagelstm.CRowJoinTable(2)
   self.params, self.grad_params = self.emb:getParameters()

  if gpu_mode then
    self:set_gpu_mode()
  end

  -- Copy embedding weights
  if config.emb_vecs ~= nil then
    self.emb.weight:copy(config.emb_vecs)
  end
  -- Copy the image embedding vectors
  if config.combine_weights ~= nil then
    self.params:copy(config.combine_weights)
  end
end

-- Returns all of the weights of this module
function ConcatLayer:getWeights()
  return self.params
end

-- Sets gpu mode
function ConcatLayer:set_gpu_mode()
  self.combine_model:cuda()
  self.emb:cuda()
end


-- Does a single forward step of concat layer, concatenating
-- Input 
function ConcatLayer:forward(word_indeces, image_feats)
   self.word_proj = self.emb:forward(word_indeces)
   res = self.combine_model:forward({self.word_proj, image_feats})
   return res
end

function ConcatLayer:backward(word_indices, image_feats, err)
   emb_errors = self.combine_model:backward({self.word_proj, image_feats}, err)

   -- get the image and word projection errors
   image_emb_errors = emb_errors[2]
   word_proj_errors = emb_errors[1]

   self.emb:backward(word_indices, word_proj_errors)
end

-- Returns size of outputs of this combine module
function ConcatLayer:getOutputSize()
  return self.emb_dim + self.image_dim
end

function ConcatLayer:getParameters()
  return self.params, self.grad_params
end

-- zeros out the gradients
function ConcatLayer:zeroGradParameters() 
  self.emb:zeroGradParameters()
  self.combine_model:zeroGradParameters()
end

function ConcatLayer:getModules() 
  return {self.emb}
end

function ConcatLayer:normalizeGrads(batch_size)
  self.emb.gradWeight:div(batch_size)
end
