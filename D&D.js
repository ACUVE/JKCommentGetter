// TS�t�@�C���𑼂̃X�N���v�g�Ƃ����s�t�@�C���Ɋۓ������ăj�R�j�R����̃R�����g�������_�E�����[�h�o���邩������Ȃ��悤�ɂ���X�N���v�g
// License: WTFPL <http://www.wtfpl.net/txt/copying/>

// ���g����
// �@0. JKCommentGetter.rb�Ɠ����t�H���_�ɂ��̃t�@�C����u���AJKCommentGetter.rb�̐ݒ���ς܂���
// �@1. tsrenamec �𓯂��t�H���_�ɒu���ihttp://toro.2ch.net/test/read.cgi/avi/1330008877/626�j>>626�� �y�� ����� �Ɋ���
// �@2. ���̃X�N���v�g�̃A�C�R���Ƀt�@�C�����h���b�O�A���h�h���b�v����
// �@3. �_�E�����[�h�o���邩������Ȃ�
// ���p�����[�^�[��-b�����Ȃ��Ƃ��A�X�N���v�g�̂���t�H���_�ɏo�͂���܂�
// ��-f�����Ȃ��Ɖ��̂��i�����̊��ł́j�~�܂�܂�

// ���ݒ�
// �@�_�E�����[�h���邽�߃X�N���v�g�̃t�@�C����
var DOWNLOADSCRIPT = 'JKCommentGetter.rb';
// �@TsRenamec �̃t�@�C����
var TSRENAMEC = 'tsrenemec.exe';
// �@�_�E�����[�h���邽�߂̃X�N���v�g�ɓn���p�����[�^
var DOWNLOADSCRIPTARG = '-f -d -w';
// �@���O�t�@�C���̃R�����g�Ƀ_�E�����[�h���̃t�@�C�������������ނ��ۂ�
var COMMENTFILENAME = true;
// �@Ruby���N������R�}���h
var RUBYCOMMAND = 'ruby';
// �@tsrename���o�͂���`�����l������jk*�Ƃ̑Ή��\
function ChToJk(ch){
	return {
		'�m�g�j�����E����': 'jk1',
		'���{�e���r': 'jk4',
		'�e���r����': 'jk7',
		'�t�W�e���r�W����': 'jk8',
		'�s�n�j�x�n�@�l�w': 'jk9'
	}[ch];
}

/////////////////////////////////////////////////////////////////////
var shell = WScript.CreateObject('WScript.Shell');
if(!shell) WScript.Quit(-1);
if(WScript.FullName.match(/wscript\.exe$/i)){
	// WScript�̂Ƃ���CScript�ł��Ȃ���
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

WScript.Echo('Enter�������ďI�����܂�')
WScript.StdIn.ReadLine()

function main(path){
	logging(path + ' ����ǂݎ���ăR�����g�̃_�E�����[�h���s���܂�');
	try{
		var exe = shell.Exec(PATH + '\\' + TSRENAMEC + ' "' + path + '" "@YY@MM@DD@SH@SM@SS/@EH@EM@ES/@CH"');	// �p�X�� " ������Ƒʖڂ����BLinux�Ƃ��B
	}catch(e){}
	if(exe){
		while(exe.Status != 1) WScript.Sleep(100);
		
		if(exe.StdErr.ReadLine() == ''){	// Success!
			logging('�@' + TSRENAMEC + ' �ɂ���͐���')
			var out = exe.StdOut.ReadLine();
			var m = out.match(/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\/(\d\d)(\d\d)(\d\d)\/(.+)$/);
			if(m){
				var start_time = (new Date(m[1] - 0, m[2] - 1, m[3] - 0, m[4] - 0, m[5] - 0, m[6] - 0)).getTime() / 1000;
				var end_time = (new Date(m[1] - 0, m[2] - 1, m[3] - 0, m[7] - 0, m[8] - 0, m[9] - 0)).getTime() / 1000;
				if(start_time > end_time){ end_time += 24 * 60 * 60; }
				var jknum = ChToJk(m[10]);
				if(jknum){
					logging('�@�R�����g�_�E�����[�h���J�n')
					// -b ��t���Ă��邪�A�����w�肳�ꂽ�ꍇ��ԍŌ�̂��̂����p�����̂�DOWNLOADSCRIPTARG�̎w��͖��ʂɂ͂Ȃ�Ȃ�
					var exe2 = shell.Exec(RUBYCOMMAND + ' "' + PATH + '\\' + DOWNLOADSCRIPT + '" ' + jknum + ' ' + start_time + ' ' + end_time + ' -b "' + PATH + '"' + (COMMENTFILENAME ? ' -o "' + path + '"' : '') + ' ' + DOWNLOADSCRIPTARG);
					while(exe2.Status != 1){
						// ���Ӗ��ɓǂݔ�΂�
						while(!exe2.StdErr.AtEndOfLine){exe2.StdErr.ReadLine();}
						while(!exe2.StdOut.AtEndOfLine){exe2.StdOut.ReadLine();}
						WScript.Sleep(100);
					}
					if(exe2.ExitCode != 0){
						logging('�@�G���[�������������A�R�����g��1�������܂���ł���');
					}else{
						logging('�@�_�E�����[�h�����I')
					}
				}else{
					logging('�@�`�����l�� ' + m[10] + ' �ɑΉ�����jk*���o�^����Ă��܂���');
				}
			}
		}else{
			logging('�@' + TSRENAMEC + ' �����s���܂���');
		}
	}else{
		logging('�@' + TSRENAMEC + ' ���N���ł��܂���ł���');
	}
}

function logging(str){
	WScript.Echo('log: ' + str);
}
