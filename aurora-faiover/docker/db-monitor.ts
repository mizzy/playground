import { Kysely, PostgresDialect, sql } from 'kysely';
import { Pool } from 'pg';

interface Database {
  // 空のインターフェース - RAWクエリのみ実行するため
}

class DatabaseMonitor {
  private db!: Kysely<Database>;
  private pool!: Pool;
  private isRunning = false;

  constructor() {
    this.initializeDatabase();
    console.log('🔗 Database monitor initialized');
    console.log(`📍 Target host: ${process.env.DB_HOST}`);
  }

  private initializeDatabase() {
    this.pool = new Pool({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: 'testdb',
      port: 5432,
      ssl: false,
      //max: 5,
      //min: 1,
      // idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });

    // エラーハンドリングを追加
    this.pool.on('error', (err) => {
      console.log(`🔌 [${new Date().toISOString()}] Pool error (continuing): ${err.message}`);
    });

    this.pool.on('connect', () => {
      console.log(`🔌 [${new Date().toISOString()}] New client connected to pool`);
    });

    this.pool.on('remove', () => {
      console.log(`🔌 [${new Date().toISOString()}] Client removed from pool`);
    });

    this.db = new Kysely<Database>({
      dialect: new PostgresDialect({
        pool: this.pool,
      }),
    });
  }


  async testConnection(): Promise<boolean> {
    try {
      const startTime = Date.now();

      // タイムアウト付きでクエリを実行
      const result = await Promise.race([
        sql`SELECT 1 as test`.execute(this.db),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Query timeout')), 10000)
        )
      ]) as any;

      const endTime = Date.now();
      const duration = endTime - startTime;

      console.log(`✅ [${new Date().toISOString()}] DB connection OK (${duration}ms) - Result: ${JSON.stringify(result.rows[0])}`);
      return true;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.log(`❌ [${new Date().toISOString()}] DB connection FAILED: ${errorMessage}`);

      // エラーをログに記録するだけで、再初期化は行わない

      return false;
    }
  }

  async start(): Promise<void> {
    this.isRunning = true;
    console.log('🚀 Starting database connection monitor...');

    while (this.isRunning) {
      try {
        await this.testConnection();
      } catch (error) {
        // 予期しないエラーをキャッチして継続
        console.log(`🚨 [${new Date().toISOString()}] Unexpected error in monitor loop: ${error}`);
        console.log(`🔄 [${new Date().toISOString()}] Monitor continuing...`);
      }
      await this.sleep(1000);
    }
  }

  stop(): void {
    this.isRunning = false;
    console.log('🛑 Database monitor stopped');
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async cleanup(): Promise<void> {
    try {
      if (this.db) {
        await this.db.destroy();
      }
      if (this.pool) {
        await this.pool.end();
      }
      console.log('🧹 Database connection cleaned up');
    } catch (error) {
      console.error('Error during cleanup:', error);
    }
  }
}

// メイン実行部分
async function main() {
  const monitor = new DatabaseMonitor();

  // Graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('📥 Received SIGTERM, shutting down gracefully...');
    monitor.stop();
    await monitor.cleanup();
    process.exit(0);
  });

  process.on('SIGINT', async () => {
    console.log('📥 Received SIGINT, shutting down gracefully...');
    monitor.stop();
    await monitor.cleanup();
    process.exit(0);
  });

  try {
    await monitor.start();
  } catch (error) {
    console.error('💥 Monitor crashed:', error);
    await monitor.cleanup();
    process.exit(1);
  }
}

// Start the monitor immediately
main().catch(console.error);
