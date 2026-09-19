using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using Microsoft.Win32;

internal static class CruSDiscord
{
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 65536 };
    static Process Parent;
    static string StatePath;
    static string ApplicationId;
    static string LastStatus;
    static string PipePrefix = "discord-ipc-";

    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            if (args.Length < 3) return;
            Parent = Process.GetProcessById(int.Parse(args[0]));
            StatePath = Path.GetFullPath(args[1]);
            ApplicationId = args[2];
            ulong id;
            if (!ulong.TryParse(ApplicationId, out id)) return;
            if (args.Length == 4 && args[3].StartsWith("crus-test-")) PipePrefix = args[3];
            if (PipePrefix == "discord-ipc-") RegisterSteam();
            while (Alive())
            {
                try { Connect(); }
                catch (Exception error) { Status("disconnected", error.GetBaseException().Message); }
                for (int i = 0; i < 20 && Alive(); i++) Thread.Sleep(250);
            }
            Status("stopped", "Game closed");
        }
        catch (Exception) { }
    }

    static bool Alive()
    {
        try { return !Parent.HasExited && File.Exists(StatePath); }
        catch (Exception) { return false; }
    }

    static void RegisterSteam()
    {
        try
        {
            using (var steam = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam"))
            {
                string executable = steam == null ? null : steam.GetValue("SteamExe") as string;
                if (String.IsNullOrEmpty(executable) || !File.Exists(executable)) return;
                using (var protocol = Registry.CurrentUser.CreateSubKey(@"Software\Classes\discord-" + ApplicationId))
                {
                    protocol.SetValue("", "URL:Cruelty Squad Discord invite");
                    protocol.SetValue("URL Protocol", "");
                    using (var command = protocol.CreateSubKey(@"shell\open\command"))
                        command.SetValue("", "\"" + executable + "\" steam://rungameid/1388770");
                }
            }
        }
        catch (Exception error) { Status("error", "Cannot register Steam launch: " + error.Message); }
    }

    static void Join(Dictionary<string, object> response)
    {
        object raw;
        if (!response.TryGetValue("data", out raw)) return;
        var data = raw as Dictionary<string, object>;
        if (data == null || !data.TryGetValue("secret", out raw) || !(raw is string)) return;
        string secret = (string)raw;
        string[] parts = secret.Split(':');
        if (parts.Length != 3 || parts[0] != "crus1") return;
        for (int i = 1; i < 3; i++)
        {
            long id;
            if (!Int64.TryParse(parts[i], out id) || id <= 0 || id.ToString() != parts[i]) return;
        }
        try
        {
            string temporary = StatePath + ".join.tmp";
            File.WriteAllText(temporary, secret, new UTF8Encoding(false));
            if (File.Exists(StatePath + ".join")) File.Delete(StatePath + ".join");
            File.Move(temporary, StatePath + ".join");
        }
        catch (IOException error) { Status("error", "Cannot deliver Discord invite: " + error.Message); }
    }

    static void Status(string state, string message)
    {
        string status = Json.Serialize(new { state = state, message = message });
        if (status == LastStatus) return;
        LastStatus = status;
        try { File.WriteAllText(StatePath + ".status", status, new UTF8Encoding(false)); }
        catch (IOException) { }
    }

    static void Connect()
    {
        NamedPipeClientStream pipe = null;
        for (int i = 0; i < 10 && Alive(); i++)
        {
            var candidate = new NamedPipeClientStream(".", PipePrefix + i, PipeDirection.InOut, PipeOptions.Asynchronous);
            try { candidate.Connect(100); pipe = candidate; break; }
            catch (TimeoutException) { candidate.Dispose(); }
            catch (IOException) { candidate.Dispose(); }
        }
        if (pipe == null) { Status("waiting", "Waiting for Discord desktop"); return; }
        using (pipe)
        {
            Write(pipe, 0, Json.Serialize(new { v = 1, client_id = ApplicationId }));
            Task<Frame> incoming = Read(pipe);
            bool ready = false;
            DateTime connectedAt = DateTime.UtcNow;
            DateTime lastSend = DateTime.MinValue;
            string lastActivity = null;
            while (Alive())
            {
                if (incoming.IsCompleted)
                {
                    Frame frame = incoming.GetAwaiter().GetResult();
                    if (frame.Opcode == 2) throw new IOException("Discord closed the connection");
                    if (frame.Opcode == 3) Write(pipe, 4, frame.Body);
                    if (frame.Opcode == 1)
                    {
                        var response = Json.Deserialize<Dictionary<string, object>>(frame.Body);
                        object evt;
                        if (response.TryGetValue("evt", out evt) && Convert.ToString(evt) == "READY")
                        {
                            ready = true;
                            Status("connected", "Discord connected");
                            Write(pipe, 1, Json.Serialize(new { cmd = "SUBSCRIBE", evt = "ACTIVITY_JOIN", nonce = Guid.NewGuid().ToString() }));
                        }
                        else if (Convert.ToString(evt) == "ACTIVITY_JOIN" && response.ContainsKey("cmd") && Convert.ToString(response["cmd"]) == "DISPATCH")
                        { Join(response); }
                        else if (Convert.ToString(evt) == "ERROR")
                        { Status("error", Json.Serialize(response.ContainsKey("data") ? response["data"] : null)); }
                        else if (response.ContainsKey("cmd") && Convert.ToString(response["cmd"]) == "SET_ACTIVITY")
                        {
                            Status("active", "Discord accepted the activity");
                            try { File.WriteAllText(StatePath + ".accepted", frame.Body, new UTF8Encoding(false)); }
                            catch (IOException) { }
                        }
                    }
                    incoming = Read(pipe);
                }
                if (!ready && DateTime.UtcNow - connectedAt > TimeSpan.FromSeconds(5)) throw new IOException("Discord handshake timed out");
                if (ready && DateTime.UtcNow - lastSend >= TimeSpan.FromSeconds(5))
                {
                    string activity;
                    try
                    {
                        using (var file = new FileStream(StatePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                        using (var reader = new StreamReader(file)) activity = reader.ReadToEnd();
                        var data = Json.Deserialize<Dictionary<string, object>>(activity);
                        if (activity != lastActivity)
                        {
                            Write(pipe, 1, Json.Serialize(new { cmd = "SET_ACTIVITY", args = new { pid = Parent.Id, activity = data }, nonce = Guid.NewGuid().ToString() }));
                            lastActivity = activity;
                            lastSend = DateTime.UtcNow;
                        }
                    }
                    catch (ArgumentException) { }
                    catch (FileNotFoundException) { break; }
                }
                Thread.Sleep(100);
            }
            if (ready)
                Write(pipe, 1, Json.Serialize(new { cmd = "SET_ACTIVITY", args = new { pid = Parent.Id, activity = (object)null }, nonce = Guid.NewGuid().ToString() }));
        }
    }

    static void Write(NamedPipeClientStream pipe, int opcode, string text)
    {
        byte[] payload = Encoding.UTF8.GetBytes(text);
        byte[] frame = new byte[payload.Length + 8];
        Buffer.BlockCopy(BitConverter.GetBytes(opcode), 0, frame, 0, 4);
        Buffer.BlockCopy(BitConverter.GetBytes(payload.Length), 0, frame, 4, 4);
        Buffer.BlockCopy(payload, 0, frame, 8, payload.Length);
        if (!pipe.WriteAsync(frame, 0, frame.Length).Wait(2000)) throw new IOException("Discord write timed out");
    }

    sealed class Frame { public int Opcode; public string Body; }

    static async Task<Frame> Read(NamedPipeClientStream pipe)
    {
        byte[] header = new byte[8];
        await ReadExactly(pipe, header);
        int count = BitConverter.ToInt32(header, 4);
        if (count < 0 || count > 65536) throw new IOException("Invalid Discord frame length");
        byte[] body = new byte[count];
        await ReadExactly(pipe, body);
        return new Frame { Opcode = BitConverter.ToInt32(header, 0), Body = Encoding.UTF8.GetString(body) };
    }

    static async Task ReadExactly(NamedPipeClientStream pipe, byte[] data)
    {
        int offset = 0;
        while (offset < data.Length)
        {
            int count = await pipe.ReadAsync(data, offset, data.Length - offset);
            if (count == 0) throw new EndOfStreamException("Discord disconnected");
            offset += count;
        }
    }
}
