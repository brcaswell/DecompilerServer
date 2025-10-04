using System;

namespace TestLibrary
{
#if FILEWATCHER_TEST || UNITY_DEV_SIM
    /// <summary>
    /// Simulates Unity MonoBehaviour patterns for file watcher testing
    /// </summary>
    public class GameManager
    {
        public static GameManager Instance { get; private set; } = new();
        
        public int PlayerScore { get; set; }
        public bool GameActive { get; set; }
        public DateTime LastModified { get; set; } = DateTime.Now; // Trigger rebuild
        
#if FILEWATCHER_TEST
        // File watcher test - simple version
        public void StartGame()
        {
            GameActive = true;
            PlayerScore = 0;
            Console.WriteLine("Game started (FileWatcher test build)");
        }
#endif

#if UNITY_DEV_SIM
        // Unity dev simulation - more complex version
        public void StartGame()
        {
            GameActive = true;
            PlayerScore = 0;
            InitializeSystems();
            Console.WriteLine("Game started (Unity dev simulation build)");
        }
        
        private void InitializeSystems()
        {
            // Simulate more complex Unity initialization
            LoadPlayerData();
            SetupUI();
            StartCoroutines();
        }
        
        private void LoadPlayerData() { /* Simulate data loading */ }
        private void SetupUI() { /* Simulate UI setup */ }
        private void StartCoroutines() { /* Simulate coroutine startup */ }
#endif
        
        public void UpdateScore(int points)
        {
            PlayerScore += points;
        }
        
        public void EndGame()
        {
            GameActive = false;
            Console.WriteLine($"Game ended. Final score: {PlayerScore}");
        }
    }
    
    /// <summary>
    /// Simulates Unity component patterns
    /// </summary>
    public class PlayerController
    {
        public float Speed { get; set; } = 5.0f;
        public Vector3 Position { get; set; }
        
        public void Move(Vector3 direction)
        {
            Position += direction * Speed;
        }
        
#if UNITY_DEV_SIM
        // More complex Unity-like behavior in dev simulation
        public void FixedUpdate()
        {
            ApplyPhysics();
            CheckCollisions();
        }
        
        private void ApplyPhysics() { /* Simulate physics */ }
        private void CheckCollisions() { /* Simulate collision detection */ }
#endif
    }
    
    /// <summary>
    /// Simple Vector3 simulation for Unity-like patterns
    /// </summary>
    public struct Vector3
    {
        public float X, Y, Z;
        
        public Vector3(float x, float y, float z)
        {
            X = x; Y = y; Z = z;
        }
        
        public static Vector3 operator +(Vector3 a, Vector3 b)
            => new(a.X + b.X, a.Y + b.Y, a.Z + b.Z);
            
        public static Vector3 operator *(Vector3 v, float scalar)
            => new(v.X * scalar, v.Y * scalar, v.Z * scalar);
    }
    
    /// <summary>
    /// Build configuration dependent features
    /// </summary>
    public static class BuildInfo
    {
        public static string Configuration =>
#if FILEWATCHER_TEST
            "FileWatcher Test Build";
#elif UNITY_DEV_SIM  
            "Unity Development Simulation";
#else
            "Standard Test Build";
#endif
        
        public static DateTime BuildTime => DateTime.Now;
        
        public static int FeatureCount =>
#if FILEWATCHER_TEST
            5; // Minimal features for quick testing
#elif UNITY_DEV_SIM
            15; // Extended features for realistic simulation
#else
            8; // Standard test features
#endif
    }
#endif
}