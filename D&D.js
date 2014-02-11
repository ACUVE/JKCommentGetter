// TSファイルを他のスクリプトとか実行ファイルに丸投げしてニコニコ動画のコメントを自動ダウンロード出来るかもしれないようにするスクリプト
// License: WTFPL <http://www.wtfpl.net/txt/copying/>

// ☆使い方
// 　0. JKCommentGetter.rbと同じフォルダにこのファイルを置き、JKCommentGetter.rbの設定を済ませる
// 　1. tsrenamec を同じフォルダに置く（http://toro.2ch.net/test/read.cgi/avi/1330008877/626）>>626氏 及び 原作者 に感謝
// 　2. このスクリプトのアイコンにファイルをドラッグアンドドロップする
// 　3. ダウンロード出来るかもしれない
// ※パラメーターに-bをつけないとき、スクリプトのあるフォルダに出力されます
// ※-fをつけないと何故か（自分の環境では）止まります

// ☆設定
// 　ダウンロードするためスクリプトのファイル名
var DOWNLOADSCRIPT = 'JKCommentGetter.rb';
// 　TsRenamec のファイル名
var TSRENAMEC = 'tsrenemec.exe';
// 　ダウンロードするためのスクリプトに渡すパラメータ
var DOWNLOADSCRIPTARG = '-f -d -w';
// 　ログファイルのコメントにダウンロード元のファイル名を書き込むか否か
var COMMENTFILENAME = true;
// 　Rubyを起動するコマンド
var RUBYCOMMAND = 'ruby';
// 　tsrenameが出力するチャンネル名とjk*との対応表
function ChToJk(ch){
	return {
		'ＮＨＫ総合・東京': 'jk1',
		'日本テレビ': 'jk4',
		'テレビ東京': 'jk7',
		'フジテレビジョン': 'jk8',
		'ＴＯＫＹＯ　ＭＸ': 'jk9'
	}[ch];
}

/////////////////////////////////////////////////////////////////////
var shell = WScript.CreateObject('WScript.Shell');
if(!shell) WScript.Quit(-1);
if(WScript.FullName.match(/wscript\.exe$/i)){
	// WScriptのときはCScriptでやりなおす
	str = '';
	for(var i = 0; i < WScript.Arguments.length; ++i){
		str += ' "' + WScript.Arguments(i) + '"';
	}
	shell.Run('cscript //Nologo "' + WScript.ScriptFullName + '"' + str);
	WScript.Quit(0);
}

var PATH = (function(){
	var fso = WScript.CreateObject('Scripting.FileSystemObject');
	var file = fso.GetFile(WScript.ScriptFullName);
	return file.ParentFolder.Path;
})();


for(var i = 0; i < WScript.Arguments.length; ++i){
	main(WScript.Arguments(i));
}

WScript.Echo('Enterを押して終了します')
WScript.StdIn.ReadLine()

function main(path){
	logging(path + ' から読み取ってコメントのダウンロードを行います');
	try{
		var exe = shell.Exec(PATH + '\\' + TSRENAMEC + ' "' + path + '" "@YY@MM@DD@SH@SM@SS/@EH@EM@ES/@CH"');	// パスに " があると駄目かも。Linuxとか。
	}catch(e){}
	if(exe){
		while(exe.Status != 1) WScript.Sleep(100);
		
		if(exe.StdErr.ReadLine() == ''){	// Success!
			logging('　' + TSRENAMEC + ' による解析成功')
			var out = exe.StdOut.ReadLine();
			var m = out.match(/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\/(\d\d)(\d\d)(\d\d)\/(.+)$/);
			if(m){
				var start_time = (new Date(m[1] - 0, m[2] - 1, m[3] - 0, m[4] - 0, m[5] - 0, m[6] - 0)).getTime() / 1000;
				var end_time = (new Date(m[1] - 0, m[2] - 1, m[3] - 0, m[7] - 0, m[8] - 0, m[9] - 0)).getTime() / 1000;
				if(start_time > end_time){ end_time += 24 * 60 * 60; }
				var jknum = ChToJk(m[10]);
				if(jknum){
					logging('　コメントダウンロードを開始')
					// -b を付けているが、複数指定された場合一番最後のものが利用されるのでDOWNLOADSCRIPTARGの指定は無駄にはならない
					var exe2 = shell.Exec(RUBYCOMMAND + ' "' + PATH + '\\' + DOWNLOADSCRIPT + '" ' + jknum + ' ' + start_time + ' ' + end_time + ' -b "' + PATH + '"' + (COMMENTFILENAME ? ' -o "' + path + '"' : '') + ' ' + DOWNLOADSCRIPTARG);
					while(exe2.Status != 1){
						// 無意味に読み飛ばす
						while(!exe2.StdErr.AtEndOfLine){exe2.StdErr.ReadLine();}
						while(!exe2.StdOut.AtEndOfLine){exe2.StdOut.ReadLine();}
						WScript.Sleep(100);
					}
					if(exe2.ExitCode != 0){
						logging('　エラーが発生したか、コメントが1つも得られませんでした');
					}else{
						logging('　ダウンロード完了！')
					}
				}else{
					logging('　チャンネル ' + m[10] + ' に対応するjk*が登録されていません');
				}
			}
		}else{
			logging('　' + TSRENAMEC + ' が失敗しました');
		}
	}else{
		logging('　' + TSRENAMEC + ' が起動できませんでした');
	}
}

function logging(str){
	WScript.Echo('log: ' + str);
}
