const { Plugin, Notice } = require('obsidian');
const { exec } = require('child_process');

module.exports = class ZundamonWallHittingPlugin extends Plugin {
    async onload() {
        console.log('Loading Zundamon Wall-Hitting plugin...');

        // 1. 左リボン（サイドバー）に壁打ちアイコンボタンを追加
        this.addRibbonIcon('bot', '🌱 ずんだもんと壁打ち開始 (MyOllama)', () => {
            this.startWallHittingWithZundamon();
        });

        // 2. コマンドパレット (Cmd+P) にコマンドを追加
        this.addCommand({
            id: 'start-zundamon-wall-hitting',
            name: '🌱 ずんだもんと現在のノートで壁打ち開始',
            callback: () => {
                this.startWallHittingWithZundamon();
            }
        });
    }

    onunload() {
        console.log('Unloading Zundamon Wall-Hitting plugin...');
    }

    startWallHittingWithZundamon() {
        const activeFile = this.app.workspace.getActiveFile();
        let targetPath = '';
        let title = '無題';

        if (activeFile) {
            targetPath = this.app.vault.adapter.getFullPath(activeFile.path);
            title = activeFile.basename;
        }

        new Notice(`🌱 ずんだもんを召喚中...\n「${title}」の壁打ちを開始するのだ！`, 4000);

        // MyOllama アプリをカスタムURLスキームまたは open コマンドで起動してノートを渡す
        if (targetPath) {
            const encodedPath = encodeURIComponent(targetPath);
            const cmd = `open "myollama://sync-note?path=${encodedPath}" || open -a MyOllama`;
            exec(cmd, (err) => {
                if (err) {
                    // フォールバック: 通常起動
                    exec('open -a MyOllama');
                }
            });
        } else {
            exec('open "myollama://start-call" || open -a MyOllama');
        }
    }
};
