# History
# v1 - 2023-06-29
# v2 - 2023-07-01
#    - 시리얼 통신 / 핸들링 판단 기능 부분적 추가
#    - HSV 필터 약간 수정
#    - 신호등 판단을 위해 제공된 라이브러리 함수도 병합
# v3 - 시리얼 통신 망했는데 그거 대충 수정해놓고 결과 지켜봐야 함

# Module Import
import Function_Library as fl
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import numpy as np
import cv2
import math
import time
from queue import Queue
import serial
import threading
import Function_Library as LiDAR



##################################################################
# ------------------차선 인식을 위한 함수들------------------------#

def grayscale(img): # 흑백이미지로 변환
    return cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)

def canny(img, low_threshold, high_threshold): # Canny 알고리즘
    return cv2.Canny(img, low_threshold, high_threshold)

def gaussian_blur(img, kernel_size): # 가우시안 필터
    return cv2.GaussianBlur(img, (kernel_size, kernel_size), 0)

def region_of_interest(img, vertices, color3=(255,255,255), color1=255): # ROI 셋팅

    mask = np.zeros_like(img) # mask = img와 같은 크기의 빈 이미지
    
    if len(img.shape) > 2: # Color 이미지(3채널)라면 :
        color = color3
    else: # 흑백 이미지(1채널)라면 :
        color = color1
        
    # vertices에 정한 점들로 이뤄진 다각형부분(ROI 설정부분)을 color로 채움 
    cv2.fillPoly(mask, vertices, color)
    
    # 이미지와 color로 채워진 ROI를 합침
    ROI_image = cv2.bitwise_and(img, mask)
    return ROI_image

def draw_lines(img, lines, color=[255, 0, 0], thickness=2): # 선 그리기
    for line in lines:
        for x1,y1,x2,y2 in line:
            cv2.line(img, (x1, y1), (x2, y2), color, thickness)

def draw_fit_line(img, lines, color=[255, 0, 0], thickness=10): # 대표선 그리기
        cv2.line(img, (lines[0], lines[1]), (lines[2], lines[3]), color, thickness)

def hough_lines(img, rho, theta, threshold, min_line_len, max_line_gap): # 허프 변환
    lines = cv2.HoughLinesP(img, rho, theta, threshold, np.array([]), minLineLength=min_line_len, maxLineGap=max_line_gap)
    #line_img = np.zeros((img.shape[0], img.shape[1], 3), dtype=np.uint8)
    #draw_lines(line_img, lines)

    return lines

def weighted_img(img, initial_img, α=1, β=1., λ=0.): # 두 이미지 operlap 하기
    return cv2.addWeighted(initial_img, α, img, β, λ)

def get_fitline(img, f_lines): # 대표선 구하기   
    lines = np.squeeze(f_lines)
    lines = lines.reshape(lines.shape[0]*2,2)
    rows,cols = img.shape[:2]
    output = cv2.fitLine(lines,cv2.DIST_L2,0, 0.01, 0.01)
    vx, vy, x, y = output[0], output[1], output[2], output[3]
    x1, y1 = int(((img.shape[0]-1)-y)/vy*vx + x) , img.shape[0]-1
    x2, y2 = int(((100)-y)/vy*vx + x) , int(100)
    
    result = [x1,y1,x2,y2]
    return result


#######################################################################
#---------------------------교차점 구하는 함수-------------------------#

def get_crosspt(x11, y11, x12, y12, x21, y21, x22, y22):
    if x12==x11 or x22==x21:
        print('delta x=0')
        return None
    m1 = (y12 - y11) / (x12 - x11)
    m2 = (y22 - y21) / (x22 - x21)
    if m1==m2:
        print('parallel')
        return None
    cx = (x11 * m1 - y11 - x21 * m2 + y21) / (m1 - m2)
    cy = m1 * (cx - x11) + y11

    return int(cx), int(cy)


#######################################################################
#---------------------------시리얼 통신 파트---------------------------#

def SerialCommu(comm):
    while True:
        send_value = send_op_que.get()
        if send_value is None:
            pass
        else:
            comm.write(send_value.encode())
        send_op_que.task_done()


#######################################################################
#--------------------------주행 명령 결정 함수-------------------------#

def decide_op(height, width, cross_x, cross_y, color):
    operation = ''

    if (np.abs(cross_x - width / 2) < 10):
        pass
    else:
        # 951 => Right
        # 985 => center
        # 1023 => Left
        handle_controll = int(985 + (((width / 2) - (cross_x)) / (width / 2)) * 36)
        if handle_controll <= 1023 and handle_controll >= 985:
            #operation = '2' + str(int(handle_controll)) + '\n'
            operation = '3,' + str(int(handle_controll)) + '\n'
            print('L Handling')
            print(operation)

        elif handle_controll <= 985 and handle_controll >= 951:
            #operation = '3' + str(int(handle_controll)) + '\n'
            operation = '3,' + str(int(handle_controll)) + '\n'
            print('R Handling')
            print(operation)
        # if handle_controll < 255 and handle_controll > 0:
        #     operation = '4' + str(int(handle_controll)) + '\n'
        #     print('Handling')
        #     print(operation)
        #     send_op_que.put(operation)
        else:
            pass
    
    return operation

class PID() :
    def __init__(self, kp, ki, kd):
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.p_error = 0.0
        self.i_error = 0.0
        self.d_error = 0.0
    
    def pid_control(self, cte):
        self.d_error = cte - self.p_error
        self.p_error = cte
        self.i_error += cte
        
        return self.kp * self.p_error + self.ki * self.i_error + self.kd * self.d_error

def send_op(comm, send_value):
    comm.write(send_value.encode())
    while (1) :
        char = comm.read()
        if char == b'q':
            break
        
def handling_filter(handling):
    if handling > 1023:
        return 1023
    elif handling < 951:
        return 951
    else:
        return handling

STOP_PROG_flag = False
TRAFFIC_START_flag = False

def Lidar_run(env_l):
    counter = 0
    iterator = env_l.lidar.iter_measures("normal", 3000)
    interest_list = []
    flag = 0
    global STOP_PROG_flag
    global TRAFFIC_START_flag

    while counter < 2:
        for scan in iterator:
            flag = 0

            if scan[2] > 0 and scan[2] < 30 or scan[2] > 330 and scan[2] < 360:
                interest_list.append(scan)

            if len(interest_list) > 10:
                print(interest_list)
                for element in interest_list:
                    if element[3] == 0:
                        pass
                    elif element[3] < 800:
                        flag += 1

                if flag != 0:
                    if counter == 0:
                        STOP_PROG_flag = True
                        send_value = '4,75\n'
                        send_op(comm, send_value)
                        counter += 1
                        send_value = '5,75\n'
                        send_op(comm, send_value)
                        counter += 1
                        STOP_PROG_flag = False

                interest_list = []
                time.sleep(0.5)
                break
    
    TRAFFIC_START_flag = True
    env_l.stop()

    return 0

#######################################################################       
# ---------------------------Main Code------------------------------- #
EPOCH = 500000
CAMERA_ID = 0
FRAME_WIDTH = 640
FRAME_HEIGTH = 480

send_op_que = Queue()
left_fit_line = []
right_fit_line = []
STOP_signal = False
STOP_state = False
MODE = 3

if MODE == 1:
    # #####################################################
    # 시리얼 통신 시작
    ser = fl.libARDUINO()
    comm = ser.init(port='COM6', baudrate=9600)

    send_value = '0,255\n'
    send_op(comm, send_value)
    # #####################################################
    
    # 카메라
    env_c = fl.libCAMERA()
    ch0, ch1 = env_c.initial_setting(capnum=2)
    out = cv2.VideoWriter('output.mp4', cv2.VideoWriter_fourcc(*'XVID'), 30, (FRAME_WIDTH, FRAME_HEIGTH))
    
    # Camera Reading..
    for i in range(EPOCH):
        _, frame0, _, frame1= env_c.camera_read(ch0, ch1)
        image_1 = frame1
        image_2 = frame0

        height, width = image_1.shape[:2]
        
        hsv= cv2.cvtColor(image_1, cv2.COLOR_BGR2HSV)
        lower_blue = np.array([0, 0, 200])
        upper_blue = np.array([255, 100, 255])
        mask = cv2.inRange(hsv, lower_blue, upper_blue)
        res = cv2.bitwise_and(image_1, image_1, mask=mask)

        #res = image
        blur_img = gaussian_blur(res, 17) # Blur 효과
        canny_img = canny(res, 100, 200) # Canny edge 알고리즘

        HIGH = 0.6
        LOW  = 0.55
        region_of_interest_vertices_4side = [
            (0, height * HIGH),
            (width * 0, height * LOW),
            (width * 1, height * LOW),
            (width, height * HIGH),
        ]

        region_of_interest_vertices_4stop = [
            (0, height * 1),
            (width * 0, height * 0.5),
            (width * 1, height * 0.5),
            (width, height*1),
        ]

        vertices = np.array([region_of_interest_vertices_4side], dtype=np.int32)
        ROI_img_4side = region_of_interest(canny_img, vertices) # ROI 설정

        vertices = np.array([region_of_interest_vertices_4stop], dtype=np.int32)
        ROI_img_4stop = region_of_interest(canny_img, vertices) # ROI 설정

        result = image_1
        # image_2 = ROI_img_4side

        lines = cv2.HoughLinesP(
                        ROI_img_4side,
                        rho=1,
                        theta=np.pi / 60,
                        threshold=20,
                        lines=np.array([]),
                        minLineLength=1,
                        maxLineGap=25
                    )
        
        # # 해리스 코너 검출
        # corner = cv2.cornerHarris(ROI_img_4side, 2, 3, 0.04)
        # # 변화량 결과의 최대값 10% 이상의 좌표 구하기
        # coord = np.where(corner > 0.1* corner.max())
        # coord = np.stack((coord[1], coord[0]), axis=-1)

        # 우측 라인의 특징점을 위한 변수
        cnt_r = 0
        xr_pt = 0
        yr_pt = 0
        xr_max_pt = width / 2
        yr_max_pt = 0

        # 좌측 라인의 특징점을 위한 변수
        cnt_l = 0
        xl_pt = 0
        yl_pt = 0
        xl_max_pt = width / 2
        yl_max_pt = 0

        coord = []

        if lines is None:
            pass
        else:
            for line in lines:
                for x1, y1, x2, y2 in line:
                    x_center = int((x1 + x2) / 2)
                    y_center = int((y1 + y2) / 2)
                    coord.append( [x_center, y_center] )

        for x, y in coord:
            if x > width/2 :
                cnt_r += 1
                xr_pt += x
                yr_pt += y
                if x > xr_max_pt:
                    xr_max_pt = x
                    yr_max_pt = y
            elif x < width/2 :
                cnt_l += 1
                xl_pt += x
                yl_pt += y
                if x < xl_max_pt:
                    xl_max_pt = x
                    yl_max_pt = y

#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#

        # 기준 길이 & 핸들링 스케일
        STANDARD_R_LEN = 250
        STANDARD_L_LEN = 220
        SCALE = 120 # => 260 / 4

        # 1) 우측 차선만 감지되는 경우
        if cnt_r > 0 and cnt_l == 0:
        # if cnt_r > 0:
            # xr_pt = xr_pt // cnt_r
            # yr_pt = yr_pt // cnt_r
            xr_pt = xr_max_pt
            yr_pt = yr_max_pt
            cv2.circle(result, (xr_pt,yr_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_R_LEN
            det_len = int(xr_pt - width/2)
            if std_len > det_len:
                print('Left handling')
                # 기본적으로 987이 가변저항 값 기준 CENTER 방향
                # 1023이 좌측으로 핸들링
                #  951이 우측으로 핸들링
                #
                # 핸들이 꺾이는 정도는 SCALE을 수정하면 됨!!!!
                #
                # ****SCALE이 커지면 핸들링 정도가 둔감해지고
                # SCALE이 작아지면 핸들링 정도가 민감해진다!****
                handling = int(987 + (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Right handling')
                handling = int(987 - (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

        # 2) 좌측 차선만 감지되는 경우
        elif cnt_r == 0 and cnt_l > 0:
            xl_pt = xl_max_pt
            yl_pt = yl_max_pt
            # xl_pt = xl_pt // cnt_l
            # yl_pt = yl_pt // cnt_l
            cv2.circle(result, (xl_pt,yl_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_L_LEN
            det_len = int(width/2 - xl_pt)
            if std_len > det_len:
                print('Right handling')
                handling = int(987 - (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Left handling')
                handling = int(987 + (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

        # 3) 둘 다 감지 되지 않은 경우
        elif cnt_r == 0 and cnt_l == 0:
            pass

        # 4) 양쪽 차선이 감지된 경우 
        elif cnt_r > 0 and cnt_l > 0:
            # xr_pt = xr_pt // cnt_r
            # yr_pt = yr_pt // cnt_r
            xr_pt = xr_max_pt
            yr_pt = yr_max_pt
            cv2.circle(result, (xr_pt,yr_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_R_LEN
            det_len = int(xr_pt - width/2)
            if std_len > det_len:
                print('Left handling')
                # 기본적으로 987이 가변저항 값 기준 CENTER 방향
                # 1023이 좌측으로 핸들링
                #  951이 우측으로 핸들링
                #
                # 핸들이 꺾이는 정도는 SCALE을 수정하면 됨!!!!
                #
                # ****SCALE이 커지면 핸들링 정도가 둔감해지고
                # SCALE이 작아지면 핸들링 정도가 민감해진다!****
                handling = int(987 + (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Right handling')
                handling = int(987 - (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

        # 이건 그냥 카메라 기준 중심선을 그리는 함수
        cv2.line(result, (width//2, 0), (width//2, height), color=[255,0,255])
        
        env_c.image_show(result, image_2)

        # 영상 프레임 기록
        out.write(result)

        # Process Termination (If you input the 'q', camera scanning is ended.)
        if env_c.loop_break():
            #send_op_que.join()
            break

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-#

elif MODE == 2:
    # #####################################################
    # 시리얼 통신 시작
    ser = fl.libARDUINO()
    comm = ser.init(port='COM6', baudrate=9600)

    send_value = '0,150\n'
    send_op(comm, send_value)
    # #####################################################

    lane_change = 0

    env = fl.libCAMERA()
    ch0, ch1 = env.initial_setting(capnum=2)
    out = cv2.VideoWriter('output.mp4', cv2.VideoWriter_fourcc(*'XVID'), 30, (FRAME_WIDTH, FRAME_HEIGTH))

    # Camera Reading..
    for i in range(EPOCH):
        char = ''
        print(comm.in_waiting)
        if comm.in_waiting:
            char = comm.read()

        print(char)

        if char == b's':
            if lane_change == 0:
                send_value = '4,0\n'
                send_op(comm, send_value)
                lane_change += 1
            elif lane_change == 1:
                send_value = '5,0\n'
                send_op(comm, send_value)
                TRAFFIC_START_flag = True
                lane_change += 1
            else:
                pass

        _, frame0, _, frame1= env.camera_read(ch0, ch1)
        image_1 = frame1
        image_2 = frame0

        height, width = image_1.shape[:2]
        
        hsv= cv2.cvtColor(image_1, cv2.COLOR_BGR2HSV)
        lower_blue = np.array([0, 0, 225])
        upper_blue = np.array([255, 60, 255])
        mask = cv2.inRange(hsv, lower_blue, upper_blue)
        res = cv2.bitwise_and(image_1, image_1, mask=mask)

        #res = image
        blur_img = gaussian_blur(res, 17) # Blur 효과
        canny_img = canny(res, 100, 200) # Canny edge 알고리즘
        
        region_of_interest_vertices_4side = [
            (0, height * 0.6),
            (width * 0, height * 0.55),
            (width * 1, height * 0.55),
            (width, height*0.6),
        ]

        region_of_interest_vertices_4stop = [
            (0, height * 1),
            (width * 0, height * 0.5),
            (width * 1, height * 0.5),
            (width, height*1),
        ]

        vertices = np.array([region_of_interest_vertices_4side], dtype=np.int32)
        ROI_img_4side = region_of_interest(canny_img, vertices) # ROI 설정

        vertices = np.array([region_of_interest_vertices_4stop], dtype=np.int32)
        ROI_img_4stop = region_of_interest(canny_img, vertices) # ROI 설정

        result = image_1
        # image_2 = ROI_img_4side

        # 해리스 코너 검출
        corner = cv2.cornerHarris(ROI_img_4side, 2, 3, 0.04)
        # 변화량 결과의 최대값 10% 이상의 좌표 구하기
        coord = np.where(corner > 0.1* corner.max())
        coord = np.stack((coord[1], coord[0]), axis=-1)

        # 우측 라인의 특징점을 위한 변수
        cnt_r = 0
        xr_pt = 0
        yr_pt = 0
        xr_max_pt = 0
        yr_max_pt = 0

        # 좌측 라인의 특징점을 위한 변수
        cnt_l = 0
        xl_pt = 0
        yl_pt = 0
        
        for x, y in coord:
            if x > width/2 :
                cnt_r += 1
                xr_pt += x
                yr_pt += y
                if x > xr_max_pt:
                    xr_max_pt = x
                    yr_max_pt = y
            elif x < width/2 :
                cnt_l += 1
                xl_pt += x
                yl_pt += y

#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#

        # 기준 길이 & 핸들링 스케일
        STANDARD_LEN = 250
        SCALE = 60 # => 260 / 4

        # 1) 우측 차선만 감지되는 경우
        if cnt_r > 0 and cnt_l == 0:
        # if cnt_r > 0:
            xr_pt = xr_pt // cnt_r
            yr_pt = yr_pt // cnt_r
            # xr_pt = xr_max_pt
            # yr_pt = yr_max_pt
            cv2.circle(image_1, (xr_pt,yr_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_LEN
            det_len = int(xr_pt - width/2)
            if std_len > det_len:
                print('Left handling')
                # 기본적으로 987이 가변저항 값 기준 CENTER 방향
                # 1023이 좌측으로 핸들링
                #  951이 우측으로 핸들링
                #
                # 핸들이 꺾이는 정도는 SCALE을 수정하면 됨!!!!
                #
                # ****SCALE이 커지면 핸들링 정도가 둔감해지고
                # SCALE이 작아지면 핸들링 정도가 민감해진다!****
                handling = int(987 + (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Right handling')
                handling = int(987 - (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

        # 2) 좌측 차선만 감지되는 경우
        elif cnt_r == 0 and cnt_l > 0:
            xl_pt = xl_pt // cnt_l
            yl_pt = yl_pt // cnt_l
            cv2.circle(result, (xl_pt,yl_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_LEN
            det_len = int(width/2 - xl_pt)
            if std_len > det_len:
                print('Right handling')
                handling = int(987 - (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Left handling')
                handling = int(987 + (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

        # 3) 둘 다 감지 되지 않은 경우
        elif cnt_r == 0 and cnt_l == 0:
            pass

        # 4) 양쪽 차선이 감지된 경우 
        elif cnt_r > 0 and cnt_l > 0:
            # xr_pt = xr_pt // cnt_r
            # yr_pt = yr_pt // cnt_r
            xr_pt = xr_max_pt
            yr_pt = yr_max_pt
            cv2.circle(image_1, (xr_pt,yr_pt), 5, (0,0,255), 1, cv2.LINE_AA)
            std_len = STANDARD_LEN
            det_len = int(xr_pt - width/2)
            if std_len > det_len:
                print('Left handling')
                # 기본적으로 987이 가변저항 값 기준 CENTER 방향
                # 1023이 좌측으로 핸들링
                #  951이 우측으로 핸들링
                #
                # 핸들이 꺾이는 정도는 SCALE을 수정하면 됨!!!!
                #
                # ****SCALE이 커지면 핸들링 정도가 둔감해지고
                # SCALE이 작아지면 핸들링 정도가 민감해진다!****
                handling = int(987 + (std_len - det_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

            elif std_len < det_len:
                print('Right handling')
                handling = int(987 - (det_len - std_len) * (36 / SCALE) )
                send_value = '3,' + str(handling_filter(handling)) + '\n'
                print(send_value)
                send_op(comm, send_value)

#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#
#-------------------------------------------------------------------#

        # 이건 그냥 카메라 기준 중심선을 그리는 함수
        cv2.line(result, (width//2, 0), (width//2, height), color=[255,0,255])

        # 영상 프레임 기록
        out.write(result)

        # 신호등 처리부
        color, traffic = env.object_detection(image_2, sample=16, print_enable=False)
        # traffic = ROI_img_4stop
        env.image_show(result, traffic)

        if TRAFFIC_START_flag is True:
            if color == 'RED' and STOP_signal == False:
                send_value = '0,75\n'
                send_op(comm, send_value)
                print('SLOW!')
                STOP_signal = True

            if STOP_signal == True and STOP_state == True:
                if color == 'GREEN':
                    send_value = '3,987\n'
                    send_op(comm, send_value)
                    send_value = '0,100\n'
                    send_op(comm, send_value)
                    print('START!')
                    STOP_signal = False
                    STOP_state = False
                    time.sleep(2)

            elif STOP_signal == True and STOP_state == False:
                try:
                    lines = cv2.HoughLinesP(
                        ROI_img_4stop,
                        rho=6,
                        theta=np.pi / 60,
                        threshold=160,
                        lines=np.array([]),
                        minLineLength=150,
                        maxLineGap=25
                    )

                    line_x = []
                    line_y = []
                    line_filter = []

                    for line in lines:
                        for x1, y1, x2, y2 in line:
                            slope = (y2 - y1) / (x2 - x1) # <-- Calculating the slope.
                            if math.fabs(slope) > 0.1: # <-- Only consider extreme slope
                                continue
                            else: # <-- Otherwise, right group.
                                line_filter.extend(line)
                                # line_x.extend([x1, x2])
                                # line_y.extend([y1, y2])

                    stop_fit_line = line_filter[0]

                    cv2.line(image_1, [stop_fit_line[0], stop_fit_line[1]], [stop_fit_line[2], stop_fit_line[3]], color=[255, 0, 0], thickness=5)
                    cv2.imshow('img0', image_1)
                    print(stop_fit_line)
                    value = height - (stop_fit_line[1] + stop_fit_line[3]) / 2
                    print('cal:', value)
                    if value < 130:
                        send_value = '2,0\n'
                        send_op(comm, send_value)
                        STOP_state = True
                        print('STOP!')
                except:
                    pass

        # Process Termination (If you input the 'q', camera scanning is ended.)
        if env.loop_break():
            #send_op_que.join()
            break

elif MODE == 3:
    ser = fl.libARDUINO()
    comm = ser.init(port='COM6', baudrate=9600)

    send_value = '6,0\n'
    send_op(comm, send_value)

send_value = '2,0\n'
send_op(comm, send_value)

# 영상 저장
out.release()

# File End