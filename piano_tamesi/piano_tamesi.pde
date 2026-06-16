import processing.sound.*;

// メロディの周波数（修正版：最後の音が349.2）
float[] notes = {
523.3, 587.3, 523.3, 587.3, 523.3, 440.0, 440.0, 466.2, 440.0, 466.2, 440.0, 349.2, 
440.0, 349.2, 392.0, 440.0, 349.2, 392.0, 440.0, 466.2, 523.3, 523.3, 392.0, 440.0, 392.0, 
523.3, 587.3, 523.3, 587.3, 523.3, 523.3, 440.0, 440.0, 440.0, 466.2, 440.0, 466.2, 440.0, 440.0, 349.2, 
587.3, 523.3, 440.0, 523.3, 523.3, 440.0, 349.2, 440.0, 440.0, 392.0, 392.0, 349.2
};

// 各音の拍数（追加）
float[] beats = {
  0.75, 0.25, 0.75, 0.25, 1.0, 1.0, 0.75, 0.25, 0.75, 0.25, 1.0, 1.0,
  1.0, 0.5, 0.5, 1.0, 0.5, 0.5, 0.75, 0.25, 0.5, 0.5, 0.75, 0.25, 1.0,
  0.75, 0.25, 0.75, 0.25, 0.5, 0.5, 0.5, 0.5, 0.75, 0.25, 0.75, 0.25, 0.5, 0.5, 1.0,
  1.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.75, 0.25, 1.75
};

// 各倍音用のサイン波（基音 + 倍音5つ）
SinOsc[] harmonics;
int numHarmonics = 6;

// 倍音の相対的な音量（ピアノらしい減衰カーブ）
float[] harmonicAmps = {1.0, 0.8, 0.4, 0.3, 0.15, 0.1};

// 倍音比率（整数倍音）
float[] harmonicRatios = {1, 2, 3, 4, 5, 6};

int noteIndex = 0;
int noteStartTime = 0;

// 【変更】1拍の基準の長さ（ミリ秒）と、現在の音の長さ
int baseBeatDuration = 500; // この数値を小さくするとテンポが速くなります
int currentNoteDuration = 0; 

float masterVolume = 0.0;
float attackTime = 10;   // アタック（ミリ秒）
float decayTime = 150;   // ディケイ（ミリ秒）

void setup() {
  size(600, 400);
  
  // 倍音オシレータの初期化
  harmonics = new SinOsc[numHarmonics];
  for (int i = 0; i < numHarmonics; i++) {
    harmonics[i] = new SinOsc(this);
    harmonics[i].play();
    harmonics[i].amp(0);
  }
  
  noteStartTime = millis();
  // 最初の音の長さを計算して再生
  currentNoteDuration = int(baseBeatDuration * beats[noteIndex]);
  playNote(notes[noteIndex]);
}

void draw() {
  background(30, 30, 50);
  
  int elapsed = millis() - noteStartTime;
  
  // エンベロープ処理（アタック→ディケイ）
  if (elapsed < attackTime) {
    masterVolume = map(elapsed, 0, attackTime, 0, 1.0);
  } else {
    float decayElapsed = elapsed - attackTime;
    masterVolume = exp(-decayElapsed / decayTime) * 1.0;
  }
  
  // 各倍音の音量を更新
  updateHarmonicAmps();
  
  // 【変更】固定値（noteDuration）ではなく可変値（currentNoteDuration）で判定
  if (elapsed > currentNoteDuration) {
    noteIndex++;
    if (noteIndex >= notes.length) {
      noteIndex = 0; // ループ
    }
    // 次の音の長さを設定して再生
    currentNoteDuration = int(baseBeatDuration * beats[noteIndex]);
    playNote(notes[noteIndex]);
    noteStartTime = millis();
  }
  
  // 波形の可視化
  drawWaveform();
  
  // 情報表示
  fill(255);
  textSize(16);
  text("ゆきやこんこ - ピアノ風倍音合成（リズム対応版）", 20, 30);
  text("音符: " + (noteIndex + 1) + " / " + notes.length, 20, 55);
  text("周波数: " + nf(notes[noteIndex], 0, 1) + " Hz", 20, 80);
  text("現在の拍数: " + beats[noteIndex] + " 拍", 20, 105);
}

void playNote(float freq) {
  for (int i = 0; i < numHarmonics; i++) {
    harmonics[i].freq(freq * harmonicRatios[i]);
  }
}

void updateHarmonicAmps() {
  float baseAmp = 0.08; 
  for (int i = 0; i < numHarmonics; i++) {
    float decay = exp(-i * 0.3);
    harmonics[i].amp(harmonicAmps[i] * masterVolume * baseAmp * decay);
  }
}

void drawWaveform() {
  stroke(100, 200, 255);
  strokeWeight(2);
  noFill();
  
  beginShape();
  for (int x = 0; x < width; x++) {
    float t = x * 0.05;
    float y = 0;
    
    for (int i = 0; i < numHarmonics; i++) {
      float freq = notes[noteIndex] * harmonicRatios[i];
      y += sin(t * freq * 0.01) * harmonicAmps[i] * masterVolume;
    }
    
    vertex(x, height/2 + y * 80);
  }
  endShape();
}

void keyPressed() {
  if (key == ' ') {
    for (SinOsc osc : harmonics) {
      osc.amp(0);
    }
  }
}
