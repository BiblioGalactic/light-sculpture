#!/usr/bin/env python3
"""
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
DELIA DERBYSHIRE'S BBC RADIOPHONIC WORKSHOP CONSOLE
Virtual recreation of 1960s electronic music equipment
Public/portable version
"""

import tkinter as tk
from tkinter import ttk
import math
import subprocess
import threading
import time
import os
import sys

# --- Check dependencies ---
def check_sox():
    try:
        subprocess.run(["sox", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ SoX is required but not installed.")
        print("Install via Homebrew: brew install sox")
        sys.exit(1)

check_sox()

# --- Paths ---
BASE_DIR = os.path.expanduser("$HOME/light-sculpture")
os.makedirs(BASE_DIR, exist_ok=True)
CURRENT_FILE = os.path.join(BASE_DIR, "delia_current.wav")
LOOP_FILE = os.path.join(BASE_DIR, "delia_loop.wav")

# --- Vintage knob class ---
class VintageKnob:
    def __init__(self, parent, x, y, label, min_val=0, max_val=100, initial=50):
        self.parent = parent
        self.min_val = min_val
        self.max_val = max_val
        self.value = initial
        self.label = label
        
        self.canvas = tk.Canvas(parent, width=80, height=80, bg='#1a1a1a', highlightthickness=0)
        self.canvas.place(x=x, y=y)
        
        self.label_widget = tk.Label(parent, text=label, fg='#00ff00', bg='#000000',
                                     font=('Courier', 8, 'bold'))
        self.label_widget.place(x=x, y=y+85)
        
        self.value_label = tk.Label(parent, text=str(initial), fg='#00ff00', bg='#000000',
                                    font=('Courier', 10, 'bold'))
        self.value_label.place(x=x+25, y=y+100)
        
        self.angle = 0
        self.dragging = False
        
        self.canvas.bind("<Button-1>", self.start_drag)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.end_drag)
        
        self.draw_knob()
    
    def start_drag(self, event):
        self.dragging = True
    
    def end_drag(self, event):
        self.dragging = False
    
    def on_drag(self, event):
        if not self.dragging:
            return
            
        cx, cy = 40, 40
        dx = event.x - cx
        dy = event.y - cy
        if dx == 0 and dy == 0:
            return
            
        angle = math.atan2(dy, dx)
        degrees = (math.degrees(angle) + 90) % 360
        if degrees > 270:
            degrees = 270
            
        self.angle = degrees
        self.value = int(self.min_val + (degrees / 270) * (self.max_val - self.min_val))
        self.draw_knob()
        self.update_display()
    
    def draw_knob(self):
        self.canvas.delete("all")
        self.canvas.create_oval(5,5,75,75, outline='#666666', width=2, fill='#333333')
        self.canvas.create_oval(15,15,65,65, outline='#888888', width=1, fill='#222222')
        self.canvas.create_oval(37,37,43,43, fill='#444444', outline='#666666')
        angle_rad = math.radians(self.angle - 90)
        end_x = 40 + 20 * math.cos(angle_rad)
        end_y = 40 + 20 * math.sin(angle_rad)
        self.canvas.create_line(40, 40, end_x, end_y, fill='#00ff00', width=3)
        for i in range(0, 271, 30):
            tick_angle = math.radians(i - 90)
            start_x = 40 + 25 * math.cos(tick_angle)
            start_y = 40 + 25 * math.sin(tick_angle)
            end_x = 40 + 30 * math.cos(tick_angle)
            end_y = 40 + 30 * math.sin(tick_angle)
            self.canvas.create_line(start_x, start_y, end_x, end_y, fill='#666666', width=1)
    
    def update_display(self):
        self.value_label.config(text=str(self.value))

# --- Vintage button ---
class VintageButton:
    def __init__(self, parent, x, y, label, command=None):
        self.command = command
        self.button = tk.Button(parent, text=label,
                                bg='#333333', fg='#00ff00',
                                activebackground='#00ff00', activeforeground='#000000',
                                font=('Courier', 10, 'bold'),
                                relief='raised', bd=3,
                                command=self.on_click)
        self.button.place(x=x, y=y, width=80, height=30)
    
    def on_click(self):
        if self.command:
            self.command()

# --- Main console ---
class DeliasWorkshop:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("BBC RADIOPHONIC WORKSHOP - DELIA'S CONSOLE")
        self.root.geometry("800x600")
        self.root.configure(bg='#000000')
        self.root.resizable(False, False)
        
        self.status = tk.Text(self.root, height=8, width=40,
                              bg='#001100', fg='#00ff00',
                              font=('Courier', 9),
                              insertbackground='#00ff00')
        self.status.place(x=350, y=400)
        
        self.log("BBC RADIOPHONIC WORKSHOP INITIALIZED")
        self.log("DELIA'S CONSOLE READY")
        
        # Example knobs
        self.frequency = VintageKnob(self.root, 50, 130, "FREQUENCY", 20, 2000, 440)
        self.lowpass = VintageKnob(self.root, 300, 130, "LOW-PASS", 100, 8000, 1000)
        self.speed = VintageKnob(self.root, 50, 310, "SPEED", 0.1, 4.0, 1.0)
        self.echo = VintageKnob(self.root, 300, 310, "ECHO", 0, 100, 0)
        self.reverb = VintageKnob(self.root, 400, 310, "REVERB", 0, 100, 0)
        
        # Buttons
        VintageButton(self.root, 550, 130, "GENERATE", self.generate_tone)
        VintageButton(self.root, 550, 170, "PLAY", self.play_last)
        VintageButton(self.root, 550, 210, "LOOP", self.create_loop)
        VintageButton(self.root, 550, 250, "RECORD", self.start_recording)
        
        self.current_file = CURRENT_FILE
        self.monitor_controls()
    
    def log(self, message):
        self.status.insert(tk.END, f">> {message}\n")
        self.status.see(tk.END)
        self.root.update()
    
    def generate_tone(self):
        self.log("GENERATING TONE...")
        freq = self.frequency.value
        speed = self.speed.value
        low_filter = self.lowpass.value
        echo_val = self.echo.value
        reverb_val = self.reverb.value
        cmd = f"sox -n -r 44100 -b 16 {self.current_file} synth 3 sine {freq}"
        if speed != 1.0:
            cmd += f" speed {speed}"
        if low_filter < 8000:
            cmd += f" lowpass {low_filter}"
        if echo_val > 0:
            delay = echo_val / 100.0
            cmd += f" delay {delay} {delay/2}"
        if reverb_val > 0:
            cmd += f" reverb {reverb_val}"
        self.log(f"EXECUTING: {cmd}")
        try:
            subprocess.run(cmd, shell=True, check=True)
            self.log("TONE GENERATED")
        except subprocess.CalledProcessError:
            self.log("ERROR: TONE GENERATION FAILED")
    
    def play_last(self):
        self.log("PLAYING LAST TONE...")
        if os.path.exists(self.current_file):
            for player in ["afplay", "play", "open"]:
                try:
                    subprocess.run([player, self.current_file], check=True)
                    break
                except:
                    continue
        else:
            self.log("NO SOUND FILE")
    
    def create_loop(self):
        self.log("CREATING LOOP...")
        cmd = f"sox {self.current_file} {LOOP_FILE} repeat 5"
        subprocess.run(cmd, shell=True)
        self.log("LOOP CREATED")
    
    def start_recording(self):
        self.log("RECORDING MODE ACTIVATED")
    
    def monitor_controls(self):
        self.root.after(100, self.monitor_controls)
    
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    workshop = DeliasWorkshop()
    workshop.run()
