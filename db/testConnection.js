const pool = require('./connection');

async function testConnection() {
  try {
    const [rows] = await pool.query('SELECT DATABASE() AS database_name');
    console.log('MySQL 연결 성공');
    console.log('현재 연결된 DB:', rows[0].database_name);
  } catch (err) {
    console.error('MySQL 연결 실패');
    console.error('에러 내용:', err.message);
  } finally {
    await pool.end();
  }
}

testConnection();
