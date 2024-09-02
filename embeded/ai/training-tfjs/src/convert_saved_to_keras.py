import tensorflow as tf
import os
import subprocess

# 현재 작업 디렉토리를 기준으로 상대 경로 설정
base_dir = os.path.dirname(__file__)
saved_model_path = os.path.join(base_dir, '../saved_model/jarvis_model')
keras_model_path = os.path.join(base_dir, '../tfjs_model/keras_model/jarvis_model.h5')

# 경로 확인
print(f"Using SavedModel path: {saved_model_path}")
print(f"Saving Keras model to: {keras_model_path}")

# SavedModel 로드
model = tf.saved_model.load(saved_model_path)

# 모델 서명 확인
print("Model signatures:", model.signatures.keys())

# 모델 서명에서 입력과 출력을 가져오기
infer = model.signatures['serving_default']

# 입력 텐서와 출력 텐서 정의
input_signature = infer.structured_input_signature[1]
output_signature = infer.structured_outputs

# TensorSpec에서 shape 추출
input_tensor_spec = list(input_signature.values())[0]
output_tensor_spec = list(output_signature.values())[0]

input_shape = input_tensor_spec.shape.as_list()
output_shape = output_tensor_spec.shape.as_list()

# Keras 모델로 변환
def convert_saved_model_to_keras(saved_model_path):
    # TensorFlow SavedModel 로드
    model = tf.saved_model.load(saved_model_path)
    
    # 모델 서명 가져오기
    infer = model.signatures['serving_default']
    
    # 입력 텐서와 출력 텐서 정의
    input_signature = infer.structured_input_signature[1]
    output_signature = infer.structured_outputs
    
    input_tensor_spec = list(input_signature.values())[0]
    output_tensor_spec = list(output_signature.values())[0]
    
    input_shape = input_tensor_spec.shape.as_list()
    output_shape = output_tensor_spec.shape.as_list()
    
    # Keras 모델로 래핑
    # 입력의 shape을 명시
    inputs = tf.keras.Input(shape=input_shape[1:], dtype=tf.float32)
    
    # 텐서 서명을 통해 출력 생성
    def model_fn(inputs):
        return infer(inputs)['output_0']

    # Lambda 레이어로 함수 정의
    outputs = tf.keras.layers.Lambda(lambda x: model_fn(x))(inputs)
    
    # Keras 모델 정의
    keras_model = tf.keras.Model(inputs=inputs, outputs=outputs)
    return keras_model

# SavedModel을 Keras 모델로 변환
keras_model = convert_saved_model_to_keras(saved_model_path)

# Keras 모델 저장
keras_model.save(keras_model_path)

print("Keras model saved successfully.")