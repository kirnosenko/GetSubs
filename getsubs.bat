/*
@echo off & cls
set WinDirNet=%WinDir%\Microsoft.NET\Framework
IF EXIST "%WinDirNet%\v2.0.50727\csc.exe" set csc="%WinDirNet%\v2.0.50727\csc.exe"
IF EXIST "%WinDirNet%\v3.5\csc.exe" set csc="%WinDirNet%\v3.5\csc.exe"
IF EXIST "%WinDirNet%\v4.0.30319\csc.exe" set csc="%WinDirNet%\v4.0.30319\csc.exe"
%csc% /nologo /out:"%~0.exe" %0
"%~0.exe" %*
del "%~0.exe"
exit
*/

using System;
using System.Diagnostics;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

class Program
{
	static readonly string mkvPath = @"C:\Program Files\MKVToolNix\";
	static readonly string mkvInfo = mkvPath + "mkvinfo.exe";
	static readonly string mkvExtract = mkvPath + "mkvextract.exe";
	static readonly string defaultTrack = "0";
	static readonly string[] defaultLangs = new string[] { "eng", null, "und" };

	static void Main(string[] args)
	{
		Func<string> getDir = () => AppDomain.CurrentDomain.BaseDirectory;
		Func<IEnumerable<string>> getFiles = () => GetAllFilesFromDirAndSubDirs(getDir());

		if (args.Length > 0)
		{
			if (Directory.Exists(args[0])) getDir = () => args[0];
			else if (File.Exists(args[0])) getFiles = () => new string[] { Path.GetFullPath(args[0]) };
			else
			{
				PrintDone(string.Format("Invalid path {0}", args[0]));
				return;
			}
		}
		int selectedSubs = Convert.ToInt32(args.SkipWhile(a => a != "-t").Skip(1).FirstOrDefault() ?? defaultTrack);
		string[] langs = args.SkipWhile(a => a != "-l").Skip(1)
			.TakeWhile(a => !a.StartsWith("-"))
			.Select(a => a != "null" ? a : null).ToArray();

		foreach (var f in getFiles().Where(x => Path.GetExtension(x).ToLower() == ".mkv"))
		{
			Console.WriteLine("File: " + f);
			ExtractSubtitlesForFile(f, langs.Length > 0 ? langs : defaultLangs, selectedSubs);
		}
		PrintDone("Done!");
	}
	static void PrintDone(string text)
	{
		Console.WriteLine(text);
		Console.ReadKey();
	}
	static IEnumerable<string> GetAllFilesFromDirAndSubDirs(string dir)
	{
		string[] files = new string[] {};
		string[] subdirs = new string[] {};
		try
		{
			files = Directory.GetFiles(dir);
			subdirs = Directory.GetDirectories(dir);
		}
		catch (Exception)
		{
			Console.WriteLine("Could not get access to dir {0}", dir);
		}
		foreach (var f in files)
		{
			yield return f;
		}
		foreach (var subdir in subdirs)
		{
			foreach (var f in GetAllFilesFromDirAndSubDirs(subdir))
			{
				yield return f;
			}
		}
	}
	static void ExtractSubtitlesForFile(string mkvFile, string[] langs, int selectedSubs)
	{
		var subsDest = GetFilePathWithoutExtension(mkvFile) + ".srt";
		if (File.Exists(subsDest))
		{
			Console.WriteLine("Subtitles file already exists.", subsDest);
			return;
		}

		var tracks = GetTracks(mkvFile);
		var subsToSave =
			(from t in tracks
			 let langPriority = langs.SkipWhile(l => !string.Equals(t.Lang, l, StringComparison.OrdinalIgnoreCase)).Count()
			 where t.Type == "subtitles" && langPriority > 0
			 select new
			 {
				 savefile = (Func<string>)(() => ExtractSubtitleTrack(mkvFile, t.Number)),
				 priority = langPriority,
			 }).ToArray();
		if (subsToSave.Length == 0)
		{
			Console.WriteLine("No appropriate subtitles.");
			return;
		}
		if (selectedSubs >= subsToSave.Length)
		{
			Console.WriteLine("No subtitles track #{0}", selectedSubs);
			return;
		}

		var subsOrdered =
			(from s in subsToSave
			 let file = s.savefile()
			 orderby s.priority descending
			 orderby new FileInfo(file).Length descending
			 select file).ToArray();
		var subsSource = subsOrdered.Skip(selectedSubs).FirstOrDefault();
		File.Copy(subsSource, subsDest);
		foreach (var s in subsOrdered)
		{
			File.Delete(s);
		}
	}
	static string ExtractSubtitleTrack(string mkvFile, int trackID)
	{
		var subtitlesFile = Path.GetTempFileName();
		Console.Write("Track: {0} - ", trackID);
		PrintCommandProgress(mkvExtract, string.Format("\"{0}\" tracks {1}:\"{2}\"", mkvFile, trackID, subtitlesFile));
		RemoveBOM(subtitlesFile);
		return subtitlesFile;
	}
	static IEnumerable<Track> GetTracks(string mkvFile)
	{
		using (var s = GetCommandOutput(mkvInfo, string.Format("\"{0}\"", mkvFile)))
		using (TextReader reader = new StreamReader(s))
		{
			string line = null;
			Dictionary<string, string> trackData = new Dictionary<string, string>();

			while ((line = reader.ReadLine()) != null)
			{
				if (line == "|+ Tracks") break;
			}
			while ((line = reader.ReadLine()) != null)
			{
				if (!line.StartsWith("|  "))
				{
					if (trackData.Count == 0) continue;
					Track newTrack = new Track();
					if (trackData.ContainsKey("Track number"))
					{
						newTrack.Number = Convert.ToInt32(trackData["Track number"].Split(new char[] { ' ' }).First()) - 1;
					}
					if (trackData.ContainsKey("Track type"))
					{
						newTrack.Type = trackData["Track type"];
					}
					if (trackData.ContainsKey("Language"))
					{
						newTrack.Lang = trackData["Language"];
					}
					yield return newTrack;
					trackData.Clear();
				}
				else
				{
					Match m = null;
					if ((m = Regex.Match(line, @"^\|\s*\+ (?'name'[\w\s]+):\s*(?'value'.+)")).Success)
					{
						var key = m.Groups["name"].ToString();
						var value = m.Groups["value"].ToString();
						trackData.Add(key, value);
					}
				}
				if (line.StartsWith("|+")) break;
			}
		}
	}
	static void RemoveBOM(string filePath)
	{
		byte[] data = File.ReadAllBytes(filePath);
		using (var stream = File.Create(filePath))
		{
			stream.Write(data, 3, data.Length - 3);
		}
	}
	static string GetFilePathWithoutExtension(string filePath)
	{
		return
			Path.GetDirectoryName(filePath) +
			Path.DirectorySeparatorChar +
			Path.GetFileNameWithoutExtension(filePath);
	}
	static Stream GetCommandOutput(string cmd, string arguments)
	{
		MemoryStream buf = new MemoryStream();
		TextWriter writer = new StreamWriter(buf);

		RunAndWaitForExit(cmd, arguments, line => writer.WriteLine(line));

		writer.Flush();
		buf.Seek(0, SeekOrigin.Begin);
		return buf;
	}
	static void PrintCommandProgress(string cmd, string arguments)
	{
		int left = Console.CursorLeft;
		int top = Console.CursorTop;
		RunAndWaitForExit(cmd, arguments, line =>
		{
			var progress = line.Replace("Progress: ", "");
			if (progress != line)
			{
				Console.SetCursorPosition(left, top);
				Console.Write(progress);
			}
		});
		Console.WriteLine();
	}
	static void RunAndWaitForExit(string command, string arguments, Action<string> lineOutput)
	{
		ProcessStartInfo psi = new ProcessStartInfo(command, arguments);
		psi.UseShellExecute = false;
		psi.RedirectStandardOutput = true;

		Process process = new Process();
		process.StartInfo = psi;
		process.OutputDataReceived += (s, e) =>
		{
			if (e.Data != null)
			{
				lineOutput(e.Data);
			}
		};
		process.Start();
		process.BeginOutputReadLine();
		process.WaitForExit();
		if (process.ExitCode != 0)
		{
			Console.WriteLine(string.Format(
				"Process {0} with arguments {1} exit code is {2}",
				command, arguments, process.ExitCode));
		}
	}
	struct Track
	{
		public int Number;
		public string Type;
		public string Lang;
	}
}
