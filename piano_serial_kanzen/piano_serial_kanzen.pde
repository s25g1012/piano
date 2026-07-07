// ====================================================================
// Processing プログラム（ピアノ担当）シリアル通信対応修正版
// processing.sound使用・倍音合成版
// シリアル通信：1=1拍進める, 0=停止（自動ループ防止修正版）
// ====================================================================

import processing.serial.*;
import processing.sound.*;

Serial myPort;

// 楽譜データ
float[] notes = {
  523.3, 587.3, 523.3, 587.3, 523.3, 440.0, 440.0, 466.2,
  440.0, 466.2, 440.0, 349.2, 440.0, 349.2, 392.0, 440.0,
  349.2, 392.0, 440.0, 466.2, 523.3, 523.3, 392.0, 440.0,
  392.0, 523.3, 587.3, 523.3, 587.3, 523.3, 523.3, 440.0,
  440.0, 440.0, 466.2, 440.0, 466.2, 440.0, 440.0, 349.2,
  587.3, 523.3, 440.0, 523.3, 523.3, 440.0, 349.2, 440.0,
  440.0, 392.0, 392.0, 349.2
};

float[] beats = {
  0.75, 0.25, 0.75, 0.25, 1.0,  1.0,
  0.75, 0.25, 0.75, 0.25, 1.0,  1.0,
  1.0,  0.5,  0.5,  1.0,  0.5,  0.5,
  0.75, 0.25, 0.5,  0.5,  0.75, 0.25, 1.0,
  0.75, 0.25, 0.75, 0.25, 0.5,  0.5,  0.5,  0.5,
  0.75, 0.25, 0.75, 0.25, 0.5,  0.5,  1.0,
  1.0,  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,
  0.75, 0.25, 1.75
};

// 倍音合成
SinOsc[] harmonics;
int     numHarmonics   = 6;
float[] harmonicAmps   = {1.0, 0.8, 0.4, 0.3, 0.15, 0.1};
float[] harmonicRatios = {1,   2,   3,   4,   5,    6  };

// エンベロープ
float masterVolume = 0.0;
float attackTime   = 10;   // ms
float decayTime    = 150;  // ms
int   noteStartTime = 0;

// 再生状態（tick方式）
int     index          = 0;
float   ticksRemaining = 0;
boolean playing        = false;
boolean songFinished   = false;  // ★追加：曲が最後まで終わったかどうかのフラグ

// =============================================
// setup()
// =============================================
void setup() {
  size(600, 400);

  println(Serial.list());
  // ※お使いの環境に合わせて Serial.list()[2] の番号は適宜変更してください
  myPort = new Serial(this, Serial.list()[2], 9600);
  myPort.bufferUntil('\n');

  harmonics = new SinOsc[numHarmonics];
  for (int i = 0; i < numHarmonics; i++) {
    harmonics[i] = new SinOsc(this);
    harmonics[i].play();
    harmonics[i].amp(0);
  }
}

// =============================================
// draw()
// =============================================
void draw() {
  background(30, 30, 50);

  // エンベロープ更新（再生中のみ）
  if (playing) {
    int elapsed = millis() - noteStartTime;
    if (elapsed < attackTime) {
      masterVolume = map(elapsed, 0, attackTime, 0, 1.0);
    } else {
      masterVolume = exp(-(elapsed - attackTime) / decayTime);
    }
    updateHarmonicAmps();
  }

  drawWaveform();

  fill(255);
  noStroke();
  textSize(16);
  text("ゆきやこんこ - ピアノ風倍音合成", 20, 30);

  fill(playing ? color(0, 255, 128) : color(180));
  textSize(13);
  text(playing ? "● 演奏中" : "■ 停止中", 20, 55);

  if (playing && index < notes.length) {
    fill(255);
    text("音符: " + (index + 1) + " / " + notes.length,      20, 80);
    text("周波数: " + nf(notes[index], 0, 1) + " Hz",        20, 100);
    text("拍数: " + beats[index] + " 拍",                     20, 120);
  }
}

// =============================================
// serialEvent()
// =============================================
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  
  line = trim(line);
  if (line.length() == 0) return; 
  
  try {
    int v = Integer.parseInt(line);
    handleSignal(v);
  } catch (Exception e) {
    // 数字に変換できない不正なデータは安全にスルー
  }
}

void handleSignal(int v) {
  if (v == 0) {
    stopPlaying();
    songFinished = false; // ★0が来たらフラグをリセットして次の演奏に備える
  } else {
    // ★すでに曲が終わっている場合は、1が送られてきても再生（ループ）しない
    if (songFinished) return; 
    
    if (!playing) startPlaying();
    onTick();
  }
}

void startPlaying() {
  playing        = true;
  index          = 0;
  ticksRemaining = 0;
  println("演奏開始");
}

void stopPlaying() {
  if (!playing) return;
  playing        = false;
  index          = 0;
  ticksRemaining = 0;
  masterVolume   = 0;
  updateHarmonicAmps();  // 音を即座に止める
  println("演奏停止");
}

// =============================================
// onTick()：0.25拍ぶん進める
// =============================================
void onTick() {
  if (ticksRemaining > 0.25) {
    ticksRemaining -= 0.25;
    return;
  }
  
  // ★楽譜を最後まで演奏したら、終了フラグを立てて演奏を停止する（ループ防止）
  if (index >= notes.length || index < 0) {
    songFinished = true;  // 曲の終了を記録
    stopPlaying();
    return;
  }
  
  // 次の音符を鳴らす
  playNote(notes[index]);
  ticksRemaining = beats[index];
  noteStartTime  = millis();
  index++;
}

// =============================================
// playNote()：倍音の周波数をセット
// =============================================
void playNote(float freq) {
  for (int i = 0; i < numHarmonics; i++) {
    harmonics[i].freq(freq * harmonicRatios[i]);
  }
  masterVolume = 1.0;  // アタック開始
  noteStartTime = millis();
}

void updateHarmonicAmps() {
  float baseAmp = 0.08;
  for (int i = 0; i < numHarmonics; i++) {
    float decay = exp(-i * 0.3);
    harmonics[i].amp(harmonicAmps[i] * masterVolume * baseAmp * decay);
  }
}

// =============================================
// drawWaveform()
// =============================================
void drawWaveform() {
  stroke(100, 200, 255);
  strokeWeight(2);
  noFill();
  beginShape();
  for (int x = 0; x < width; x++) {
    float t = x * 0.05;
    float y = 0;
    int safeIndex = constrain(index, 0, notes.length - 1);
    for (int i = 0; i < numHarmonics; i++) {
      float freq = notes[safeIndex] * harmonicRatios[i];
      y += sin(t * freq * 0.01) * harmonicAmps[i] * masterVolume;
    }
    vertex(x, height / 2 + y * 80);
  }
  endShape();
}

void stop() {
  for (SinOsc osc : harmonics) osc.stop();
  super.stop();
}
