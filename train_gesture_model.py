import os
import glob
import zipfile
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split

# Extract dataset.zip using standard Python instead of Jupyter magic command
if os.path.exists("dataset.zip"):
    with zipfile.ZipFile("dataset.zip", "r") as zip_ref:
        zip_ref.extractall("/content/")
    print("Dataset extracted successfully.")
else:
    print("Warning: dataset.zip not found in the current directory.")

label_map = {'idle': 0, 'triangle': 1, 'rectangle': 2, 'circle': 3}

X = []
y = []

csv_files = glob.glob('/content/dataset/**/*.csv', recursive=True)

for file in csv_files:
    filename = os.path.basename(file)
    class_name = filename.split('_')[0]

    if class_name in label_map:
        df = pd.read_csv(file, usecols=['A_mag', 'G_mag'])
        if len(df) == 400:
            X.append(df.values)
            y.append(label_map[class_name])

X = np.array(X)
y = np.array(y)

print(f"Total samples: {X.shape[0]}")
print(f"Data shape: {X.shape}") 

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = models.Sequential([
    layers.Input(shape=(400, 2)),
    layers.Conv1D(16, kernel_size=5, activation='relu', padding='same'),
    layers.MaxPooling1D(pool_size=2),
    layers.Conv1D(32, kernel_size=3, activation='relu', padding='same'),
    layers.MaxPooling1D(pool_size=2),
    layers.Flatten(),
    layers.Dense(32, activation='relu'),
    layers.Dropout(0.3),
    layers.Dense(4, activation='softmax')
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
model.summary()

history = model.fit(X_train, y_train, epochs=40, batch_size=16, validation_data=(X_test, y_test))

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open('gesture_model.tflite', 'wb') as f:
    f.write(tflite_model)

print("\n gesture_model.tflite saved.")
