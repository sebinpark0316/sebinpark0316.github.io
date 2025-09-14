from ultralytics import YOLO
import cv2
import os
import numpy as np
import time

# ==============================================================================
# 1. Signal File Paths
# ==============================================================================
# Signal file for sending violation alerts to Omniverse
VIOLATION_SIGNAL_FILE_PATH = "C:/omniverse_signal/violation_signal.txt"
# Signal file for receiving system status from Omniverse
SYSTEM_STATUS_FILE_PATH = "C:/omniverse_signal/system_status.txt"
# ==============================================================================


# --- Model and Settings ---
MODEL_PATH = 'C:/Users/psb/Downloads/pt/best.pt'
model = YOLO(MODEL_PATH)
CROSSWALK_ROI = np.array([[ 601, 341 ], [ 777, 337 ], [ 732, 306 ], [ 603, 309 ]], np.int32)
INTERSECTION_ROI_1 = np.array([[ 837, 350 ], [ 875, 347 ], [ 1013, 414 ], [ 966, 424 ]], np.int32)
INTERSECTION_ROI_2 = np.array([[ 457, 444 ], [ 293, 718 ], [ 408, 719 ], [ 520, 447 ]], np.int32)
HOT_FOLDER = "C:\\pic\\camera_0_Camera3"
output_filename = 'violation_record.mp4'
fps = 10.0
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
video_writer = None
TARGET_IMAGE_COUNT = 199
processed_image_count = 0


print(f"Now monitoring the '{HOT_FOLDER}' folder...")
print(f"Waiting for system status signal from Omniverse at '{SYSTEM_STATUS_FILE_PATH}'")

# --- Main Loop ---
try:
    # <<< CHANGED: 'first_violation_signaled' is no longer needed and has been removed.
    previous_system_status = "INACTIVE"
    
    # Initialize violation signal file to '0'
    with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
        f.write("0")
    print("Violation signal file initialized to '0'.")

    while True:
        # Check System Status from Omniverse First
        try:
            with open(SYSTEM_STATUS_FILE_PATH, "r") as f:
                system_status = f.read().strip()
        except FileNotFoundError:
            print("Waiting for system_status.txt to be created by Omniverse...", end="\r")
            time.sleep(1)
            continue
        except Exception:
            time.sleep(0.1)
            continue

        # Logic to clear old images when the light turns green
        if system_status == "ACTIVE" and previous_system_status == "INACTIVE":
            print("\nGreen light detected! Clearing accumulated old images...")
            for filename in os.listdir(HOT_FOLDER):
                file_path = os.path.join(HOT_FOLDER, filename)
                try:
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                except Exception as e:
                    print(f"Error while deleting file {file_path}: {e}")
            print("Image folder cleared. Starting real-time analysis.")
            # Reset violation signal for the new green light cycle
            with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
                f.write("0")
        
        previous_system_status = system_status
        
        if system_status != "ACTIVE":
            print("System is INACTIVE (green light is off). Pausing analysis...", end="\r")
            # <<< NEW: When system is inactive, ensure the signal is '0'
            with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
                f.write("0")
            time.sleep(1)
            continue
        
        print("System is ACTIVE. Analyzing images...                         ", end="\r")

        image_files = [f for f in os.listdir(HOT_FOLDER) if f.lower().endswith(('.png', '.jpg'))]

        # <<< CHANGED: If no images, it means no objects, so signal "0"
        if not image_files:
            with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
                f.write("0")
            time.sleep(0.05)
            continue
        
        image_files.sort()
        image_name = image_files[0]
        image_path = os.path.join(HOT_FOLDER, image_name)

        try:
            frame = cv2.imread(image_path)
            if frame is None:
                os.remove(image_path)
                continue
        except Exception as e:
            print(f"File read error: {e}, skipping the file.")
            if os.path.exists(image_path):
                os.remove(image_path)
            continue
        
        if video_writer is None:
            height, width, _ = frame.shape
            video_writer = cv2.VideoWriter(output_filename, fourcc, fps, (width, height))

        violation_in_this_frame = False

        results = model.track(frame, persist=True)[0]
        if results.boxes.id is not None:
            for box in results.boxes:
                class_name = model.names[int(box.cls[0])]
                track_id = int(box.id[0])
                coords = list(map(int, box.xyxy[0]))
                x1, y1, x2, y2 = coords
                color = (0, 255, 0)
                label = f'ID:{track_id} {class_name}'
                is_violation = False

                if class_name == 'people':
                    test_points = [(x1, y1), (x2, y1), (x2, y2), (x1, y2), (int((x1+x2)/2), int((y1+y2)/2))]
                    for point in test_points:
                        if cv2.pointPolygonTest(CROSSWALK_ROI, point, False) >= 0:
                            is_violation = True
                            break 
                elif class_name in ['car', 'truck', 'bus']:
                    test_points = [(x1, y1), (x2, y1), (x2, y2), (x1, y2), (int((x1+x2)/2), int((y1+y2)/2))]
                    for point in test_points:
                        if (cv2.pointPolygonTest(INTERSECTION_ROI_1, point, False) >= 0 or
                            cv2.pointPolygonTest(INTERSECTION_ROI_2, point, False) >= 0):
                            is_violation = True
                            break
                
                if is_violation:
                    violation_in_this_frame = True
                    color = (0, 0, 255)
                    label = f'ID:{track_id} VIOLATION'
                
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
        
        # <<< CORE LOGIC CHANGE: This block now continuously updates the signal file every frame.
        if violation_in_this_frame:
            # If any violation is found in this frame, write "1"
            with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
                f.write("1")
            print("VIOLATION DETECTED! SIGNAL 1 SENT. Pausing for Omniverse to catch up...")
            time.sleep(0.2)
        else:
            # If NO violations are found in this frame, write "0"
            with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
                f.write("0")
        # <<< END OF CHANGE
        
        cv2.polylines(frame, [CROSSWALK_ROI], isClosed=True, color=(0, 255, 255), thickness=2)
        cv2.polylines(frame, [INTERSECTION_ROI_1], isClosed=True, color=(0, 255, 255), thickness=2)
        cv2.polylines(frame, [INTERSECTION_ROI_2], isClosed=True, color=(0, 255, 255), thickness=2)
        cv2.imshow("Real-time Violation Detection", frame)

        if video_writer is not None:
            video_writer.write(frame)

        os.remove(image_path)
        
        processed_image_count += 1
        print(f"Processing complete: {processed_image_count} / {TARGET_IMAGE_COUNT}", end="\r")

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        if processed_image_count >= TARGET_IMAGE_COUNT:
            print(f"\nAutomatically terminating after processing {TARGET_IMAGE_COUNT} images.")
            break

finally:
    if video_writer is not None:
        video_writer.release() 
    
    # Clean up signal files on exit
    with open(VIOLATION_SIGNAL_FILE_PATH, "w") as f:
        f.write("0")
    with open(SYSTEM_STATUS_FILE_PATH, "w") as f:
        f.write("INACTIVE")
    print("\nProgram terminated. Signal files have been reset.")
    cv2.destroyAllWindows()
