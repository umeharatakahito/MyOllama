# ずんだもんの3Dモデルの置き場所

ここに `.usdz` / `.scn` / `.dae` / `.obj` を置くと、アプリの
オペレーター画面に表示されます。ファイル名は問いません。

## 入手

公式モデルは BOOTH の「東北ずん子・ずんだもんショップ【公式】」で配布されています。

- マスコットずんだもん  https://booth.pm/ja/items/2744821
- ずんだもん（人型）    https://booth.pm/ja/items/3733351
- ミニずんだもん        https://booth.pm/ja/items/7304529

利用規約: https://zunko.jp/guideline.html

個人の非商用利用であればアプリ画面への表示が認められており、
クレジット表記も不要です（規約より）。**商用の場合は別途契約が必要**なので、
このアプリで実際の資金を運用する段階に入る前に規約を読み直してください。

## VRM を置く場合

配布物は VRM / MMD / VRChat 向けで、VRM はそのままでは読めません。
Blender で読み込んで USDZ か DAE で書き出してください。

  1. Blender に VRM アドオン（VRM_Addon_for_Blender）を入れる
  2. VRM を読み込む
  3. ファイル → エクスポート → Universal Scene Description (.usdz)
  4. 出力を このフォルダに置く

モデルが無くても、アプリも取引も普通に動きます。表示されないだけです。

## VRM をここに置くには（Blender不要）

`Zundamon.vrm` の中身は glTF なので、Python で直接変換できます。

```bash
python3 -m venv /tmp/conv && /tmp/conv/bin/pip install trimesh pillow
/tmp/conv/bin/python -c "
import trimesh
trimesh.load('Zundamon/Zundamon.vrm', file_type='glb').export('assets/mascot/zundamon.obj')"
```

テクスチャのpngとmaterial.mtlも一緒に書き出されます。
実測で 8メッシュ・34,750面・身長1.13m を SceneKit がそのまま読みました。

**注意:** 変換されるのは形とテクスチャだけです。ボーンと表情は落ちます。
表示して回すだけならこれで足ります。
