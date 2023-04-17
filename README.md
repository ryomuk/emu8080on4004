# emu8080on4004
Intel 8080 Emulator on 4004 Evaluation Board

This document is written mostly in Japanese.
If necessary, please use a translation service such as DeepL (I recommend this) or Google.

![](images/title.jpg)

## 概要
自作の4004実験用ボードと，その上で動作する8080エミュレータです．Palo Alot Tiny BASIC(4K整数型BASIC)や，Grant Searle's BASIC(8K浮動小数点BASIC)の8080移植版がほぼそのまま動くレベルの機能が実現できています．動作速度は8080実機の1/700程度です．

## 制限事項等
- P(パリティ)フラグの実装は正確ではありません．JPOやJPE実行時にAレジスタの値から計算されます．
- DAA命令の実装は正確ではありません．
- IN命令(コントロールレジスタ)はACC=0xFF(データあり)を返します．
- IN命令(データレジスタ)は4004ボードのソフトウェアで実装されたUARTのGETCHARを呼ぶので，入力されるまで止まります．
- OUT命令はAレジスタを4004ボードのシリアルポートに出力します．
- 割り込み関連命令(DI, EI)は未実装です．

## 実験ボードの仕様
### ブレッドボード版プロトタイプの仕様
- CPU: Intel 4004
- Clock: 740kHz
- DATA RAM: 4002-1 x 2 + 4002-2 x 2 (計320bit x 4)
- Program Memory
  - ROM: AT28C64B (8k x 8bit EEPROM)
    - 000H〜EFFHの3.75KB利用可能
  - RAM: HM6268(4k x 4bit SRAM)x 2個
    - 物理メモリ F00H〜FFDHの254byte x 16バンク
      (上記を論理メモリ 000H〜FDFHにマッピングしてアクセス)
- 通信ポート: 9600bps Software Serial UART (TTL level)

### Rev.2.1版の仕様(ブレッドボード版との差分)
- Program Memory
  - DATA RAM: ピンヘッダの設定により4002-1 x 4の構成も可能ですが，その場合はソフトウェアでRAM2, RAM3をアクセスしている部分を修正する必要があります．
  - ROM: AT28C64B, AT28C256, 2764, 27256をDIPスイッチで選択可能なように設計しましたが，動作確認はAT28C64Bで実施．それ以外は未確認です．
  - RAM: HM624256(1Mbit(256k x 4bit) SRAM)x 2個
    - 物理メモリ F00H〜FFDHの254byte x 256バンク
      (上記を論理メモリ 0000H〜FDFFHにマッピングしてアクセス)

## ToDO
- メモリ64KBに拡張 → Rev.2.1で実現(2023/4/12)
- プリント基板作成 → Rev.2.1で実現(2023/4/12)
- IN命令時にTESTキーを使ったSTOPボタン相当の機能の実装

## 動画
Youtubeで関連動画を公開しています．
- https://www.youtube.com/@ryomukai/videos

## ブログ
関連する情報が書いてあるかも．
- [Intel 4004 関連記事の目次@ブログの練習](https://blog.goo.ne.jp/tk-80/e/3fa1e2972737c7b7d1b83f4e7bd648a2)

## 4004関連開発事例
- [Intel 4004  50th Anniversary Project](https://www.4004.com/)
  - https://www.4004.com/busicom-replica.html
  - http://www.4004.com/2009/Busicom-141PF-Calculator_asm_rel-1-0-1.txt
- https://github.com/jim11662418/4004-SBC
- https://www.cpushack.com/mcs-4-test-boards-for-sale
- https://github.com/novi/4004MainBoard

## データシート
- http://www.bitsavers.org/components/intel/
- https://www.intel-vintage.info/intelmcs.htm

## 開発環境
- [The Macroassembler AS](http://john.ccac.rwth-aachen.de:8000/as/)

## 画像集
- ブレッドボード版のプロトタイプ
![](images/prototype.jpg)
- プロトタイプでPalo Alto BASIC実行
![](images/basic.jpg)
- Rev.2.1基板
![](images/board_rev2_1.jpg)
- ブレッドボード版とRev.2.1基板
![](images/two_boards.jpg)

## 更新履歴
- 2023/3/21: 初版公開
- 2023/4/3: SUBフラグ(NEC uPD8080A, uCOM-80用)に関するコードを削除
- 2023/4/12: 基板(Rev.2.1)に合わせていろいろ更新．ブレッドボード版はprototypeフォルダに移動
- 2023/4/15: emu.asmにレジスタ表示しながらの連続実行とTESTボタンでの停止機能を追加
- 2023/4/16: ADC, ACIにバグ(0+FFH+Carrry(1)でCarryが立たない)があったので修正．
