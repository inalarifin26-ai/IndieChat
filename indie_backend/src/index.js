require('dotenv').config(); // must load before ./app (db.js reads DB_PATH when it is first required)
const app = require('./app');

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Indie backend listening on http://localhost:${PORT}`);
});
