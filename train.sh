export PATH=/Users/david/torch/install/bin:$PATH

th image_captioning/main.lua \
-batch_size 33 \
-mem_dim 150 \
-emb_dim 100 \
-epochs 300 \
-combine_module singleaddlayer \
-learning_rate 0.1 \
-gpu_mode \
-optim rmsprop
| tee -a "log_singeaddlayer.txt"