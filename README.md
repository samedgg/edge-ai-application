# STM32-Edge-AI-Application: Gesture Recognition

## 1. Project Overview & Purpose
The primary objective of this project is to build and observe a complete Edge AI application running on a resource-constrained microcontroller. Rather than just running machine learning inferences on a powerful computer, this project demonstrates the end-to-end pipeline: collecting raw sensor data, training a custom neural network from scratch, and deploying it directly onto bare-metal hardware. It serves as a practical implementation to understand the physical limitations of microcontrollers, optimize models for tight memory boundaries, and translate mathematical signal processing into real-time gesture recognition.

## 2. Wiring
The hardware architecture is built around an STM32 Nucleo-F411RE development board communicating with an MPU6500 IMU module. The setup relies on a standard I2C communication protocol running at 100 kHz.

| MPU6500 Pin | STM32 Nucleo-F411RE Pin |
| :--- | :--- |
| VCC | 3.3V |
| GND | GND |
| SCL | PB8 |
| SDA | PB9 |

## 3. Data Acquisition & Signal Processing
To ensure accurate readings, a calibration routine runs at startup, capturing 500 samples to calculate and subtract the initial sensor drift offset. A critical engineering decision in this project was avoiding the use of raw X, Y, and Z spatial axes for the neural network. Instead, the Euclidean norms (magnitudes) for both the acceleration and gyroscope data were calculated. This mathematical approach makes the system orientation-independent, meaning a gesture drawn parallel to a desk or perpendicular to a monitor generates the same energetic signature. For dataset creation, a custom MATLAB interface was developed to visualize the 3D orientation and automatically log 4-second gesture windows (Triangle, Rectangle, Circle, and Idle) into CSV files.

<img width="230" height="240" alt="image" src="https://github.com/user-attachments/assets/652ecef0-1c97-48f5-b458-457227ad7864" />


## 4. 1D CNN Model Architecture
Building the neural network wasn't a seamless process due to strict hardware constraints. The STM32F411RE is limited to 512KB of Flash memory and 128KB of RAM. Initially, I included Batch Normalization layers to automatically scale the dataset. However, this caused the model to amplify microscopic electrical noise when the sensor was completely stationary, resulting in false "Triangle" predictions. To solve this noise issue and fit the model into the microcontroller's memory, the architecture was heavily modified. Batch normalization was removed, and aggressive MaxPooling was utilized to compress the time-series data while minimizing the parameter count. Below is the final optimized Python code used for the model:

```python
# 1D CNN Architecture 
model = models.Sequential([
    layers.Input(shape=(400, 2)), # (A_mag, G_mag)

 # Kept filters low (16 and 32) to save Flash memory
    layers.Conv1D(16, kernel_size=5, activation='relu', padding='same'),
    layers.MaxPooling1D(pool_size=2), 
    
    layers.Conv1D(32, kernel_size=3, activation='relu', padding='same'),
    layers.MaxPooling1D(pool_size=2),
    
    layers.Flatten(),
    layers.Dense(32, activation='relu'), # Reduced neurons from 64 to 32 to prevent memory overflow
    layers.Dropout(0.3), # Helps prevent overfitting on our limited data
    layers.Dense(4, activation='softmax') # 4 output classes
])
```
While this optimized model fits perfectly within the STM32's memory, the limited dataset and constrained architecture mean it can occasionally confuse shapes with similar peak characteristics, such as triangles and rectangles. Achieving absolute commercial-grade accuracy would require a significantly larger dataset and potentially an MCU with more memory to host a deeper network.

## 5. Deployment with X-CUBE-AI
The deployment phase was handled using the STMicroelectronics X-CUBE-AI tool. After analyzing the `.tflite` model to confirm it comfortably fit within the hardware limits, the generated C libraries were integrated into the firmware. A critical part of this deployment was analyzing the memory layout of the neural network. The X-CUBE-AI tool generated a memory layout graph illustrating exactly how the activation buffers are managed layer by layer during inference. Instead of allocating unique RAM space for every single layer's output, the STM32 dynamically reuses the same memory block, constantly overwriting the previous layer's data. This buffer overlaying technique is clearly visible in the memory layout graph, where the activation footprint alternates up and down but never exceeds the peak threshold of around 38 KiB. This proves how efficiently the engine optimizes RAM, allowing a complex CNN to run effortlessly within the strict 128KB limit of the Nucleo-F411RE.

<img width="600" height="400" alt="image" src="https://github.com/user-attachments/assets/c114bc22-32da-4bcc-bcf9-172ace28d58e" />

Setting up the network in the C code required manually routing these memory pointers for the AI input and output buffers. During real-time testing, a severe hardware bottleneck was discovered: fetching the acceleration and gyroscope data through separate sequential I2C calls caused massive latency, extending a 4-second recording window to nearly 10 seconds. This was resolved by utilizing a 14-byte burst read, capturing all necessary sensor data in a single I2C transaction. The system now smoothly idles until triggered by a spacebar input via UART, records exactly 4 seconds of data, and executes the inference.


## 6. Real-Time Results
The following demonstrations show the real-time physical gestures alongside the immediate AI inference outputs generated by the STM32 and printed to the serial console.

[Triangle GIF ]

[Rectangle GIF ]

[Circle GIF ]

